import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/core/connectivity/connectivity_providers.dart';
import 'package:pulsecast/core/connectivity/connectivity_service.dart';
import 'package:pulsecast/features/player/data/channel6_now_playing_service.dart';
import 'package:pulsecast/features/player/domain/models/channel6_now_playing.dart';
import 'package:pulsecast/features/player/domain/models/now_playing_info.dart';
import 'package:pulsecast/features/player/presentation/providers/player_providers.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';

/// Direct Channel 6 metadata service provider.
final channel6NowPlayingServiceProvider = Provider<Channel6NowPlayingService>((ref) {
  return Channel6NowPlayingService();
});

/// Refresh cadence for Channel 6 `GET /api/now-playing` (~10s in production,
/// automatically disabled when tests set `metadataPollingIntervalProvider` to null).
final channel6PollingIntervalProvider = Provider<Duration?>((ref) {
  final baseInterval = ref.watch(metadataPollingIntervalProvider);
  if (baseInterval == null) return null;
  return const Duration(seconds: 10);
});

/// Riverpod provider managing currently playing track metadata exclusively
/// for Channel 6 (PulseCast Radio).
final channel6NowPlayingProvider =
    NotifierProvider<Channel6NowPlayingNotifier, Channel6NowPlayingState>(
  Channel6NowPlayingNotifier.new,
);

/// Polls Channel 6's `/api/now-playing` endpoint independently from the audio
/// player so refreshing metadata never interrupts or restarts live audio.
class Channel6NowPlayingNotifier extends Notifier<Channel6NowPlayingState> {
  static const int _maxTransientErrors = 3;

  Timer? _pollTimer;
  bool _disposed = false;
  bool _isActive = false;
  bool _isForeground = true;
  bool _isFetching = false;
  int _generation = 0;
  String? _streamUrl;

  @override
  Channel6NowPlayingState build() {
    _disposed = false;

    ref.listen<Station?>(
      playerNotifierProvider.select((s) => s.currentStation),
      (previous, next) {
        if (next == null) return;
        if (next.isChannel6) {
          Future.microtask(() {
            if (_disposed) return;
            activateForChannel6(streamUrl: next.effectiveStreamUrl);
          });
        } else {
          Future.microtask(() {
            if (_disposed) return;
            deactivate();
          });
        }
      },
    );

    ref.listen<ConnectivityStatus>(connectivityStatusProvider, (prev, next) {
      if (prev == ConnectivityStatus.offline &&
          next != ConnectivityStatus.offline &&
          _isActive &&
          _isForeground &&
          !_disposed) {
        unawaited(refresh());
      }
    });

    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _isActive = false;
      _stopTimer();
    });

    final initialStation = ref.read(playerNotifierProvider).currentStation;
    if (initialStation != null && initialStation.isChannel6) {
      Future.microtask(() {
        if (_disposed) return;
        activateForChannel6(streamUrl: initialStation.effectiveStreamUrl);
      });
    }

    return const Channel6NowPlayingState();
  }

  /// Begins initial fetch + 10s periodic polling for Channel 6.
  void activateForChannel6({String? streamUrl}) {
    if (_disposed) return;
    final normalizedUrl = streamUrl;
    if (_isActive && _streamUrl == normalizedUrl) {
      if (_isForeground && _pollTimer == null) {
        _startTimer();
      }
      return;
    }

    _generation++;
    _isActive = true;
    _streamUrl = normalizedUrl;
    _isFetching = false;
    state = const Channel6NowPlayingState(isLoading: true);

    unawaited(refresh());
    if (_isForeground) {
      _startTimer();
    }
  }

  /// Stops polling and resets Channel 6 metadata when another channel is selected.
  void deactivate() {
    if (_disposed) return;
    if (!_isActive && state == const Channel6NowPlayingState()) return;
    _generation++;
    _isActive = false;
    _streamUrl = null;
    _isFetching = false;
    _stopTimer();
    state = const Channel6NowPlayingState();
  }

  /// Pauses HTTP polling while backgrounded without affecting audio playback,
  /// and refreshes immediately upon returning to the foreground.
  void setAppForeground(bool isForeground) {
    if (_disposed || _isForeground == isForeground) return;
    _isForeground = isForeground;

    if (!isForeground) {
      _stopTimer();
    } else if (_isActive) {
      unawaited(refresh());
      _startTimer();
    }
  }

  /// Fetches `/api/now-playing` once cleanly, shielding audio playback from errors.
  Future<void> refresh() async {
    if (_disposed || !_isActive || _isFetching) return;

    _isFetching = true;
    final requestGen = _generation;
    final targetStreamUrl = _streamUrl;

    if (!state.hasLoadedOnce && state.track == null && !state.isLoading) {
      state = state.copyWith(isLoading: true);
    }

    try {
      final service = ref.read(channel6NowPlayingServiceProvider);
      final fetched = await service.fetchNowPlaying(streamUrl: targetStreamUrl);
      if (_disposed || requestGen != _generation || !_isActive) return;

      final previousTrack = state.track;
      state = Channel6NowPlayingState(
        track: fetched,
        isLoading: false,
        hasLoadedOnce: true,
        hasError: false,
        consecutiveErrors: 0,
        lastUpdated: DateTime.now(),
      );

      // Keep lock-screen / notification metadata aligned when a new Channel 6 track starts
      // without touching AudioPlayer state or restarting the live stream.
      if (fetched != null && fetched != previousTrack) {
        final handler = ref.read(radioAudioHandlerProvider);
        if (handler.currentStation?.isChannel6 == true) {
          handler.updateMetadata(
            NowPlayingInfo(
              stationId: handler.currentStation!.id,
              stationName: 'PulseCast Radio',
              title: fetched.title,
              artist: fetched.artist,
            ),
          );
        }
      }
    } catch (_) {
      if (_disposed || requestGen != _generation || !_isActive) return;

      final nextErrors = state.consecutiveErrors + 1;
      state = state.copyWith(
        clearTrack: nextErrors >= _maxTransientErrors,
        isLoading: false,
        hasLoadedOnce: true,
        hasError: true,
        consecutiveErrors: nextErrors,
      );
    } finally {
      _isFetching = false;
    }
  }

  void _startTimer() {
    _stopTimer();
    if (_disposed || !_isActive) return;
    final interval = ref.read(channel6PollingIntervalProvider);
    if (interval == null) return;

    _pollTimer = Timer.periodic(interval, (_) {
      if (!_disposed && _isActive && _isForeground) {
        unawaited(refresh());
      }
    });
  }

  void _stopTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
