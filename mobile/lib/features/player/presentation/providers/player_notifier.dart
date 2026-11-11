import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/core/cache/cache_policy.dart';
import 'package:pulsecast/core/cache/cache_providers.dart';
import 'package:pulsecast/core/config/app_config.dart';
import 'package:pulsecast/core/connectivity/connectivity_providers.dart';
import 'package:pulsecast/core/connectivity/connectivity_service.dart';
import 'package:pulsecast/features/player/data/now_playing_repository.dart';
import 'package:pulsecast/features/player/domain/models/now_playing_info.dart';
import 'package:pulsecast/features/player/services/radio_audio_handler.dart';
import 'package:pulsecast/features/settings/presentation/providers/settings_providers.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import 'package:pulsecast/features/stations/presentation/providers/stations_provider.dart';
import 'player_providers.dart';
import 'player_state.dart';

class PlayerNotifier extends Notifier<PlayerState> {
  late final RadioAudioHandler _audioHandler;
  late final INowPlayingRepository _nowPlayingRepository;
  StreamSubscription<PlaybackState>? _playbackStateSub;
  StreamSubscription<String?>? _errorSub;
  StreamSubscription<bool>? _reconnectSub;
  Timer? _metadataPollTimer;

  @override
  PlayerState build() {
    _audioHandler = ref.watch(radioAudioHandlerProvider);
    _nowPlayingRepository = ref.watch(nowPlayingRepositoryProvider);

    _listenToAudioHandler();

    // Listen to network connectivity restoration
    ref.listen(connectivityStatusProvider, (previous, next) {
      if (previous == ConnectivityStatus.offline &&
          (next == ConnectivityStatus.online ||
              next == ConnectivityStatus.serverUnavailable)) {
        if (state.errorMessage?.contains('internet connection') == true) {
          state = state.copyWith(clearError: true);
        }
      }
    });

    ref.onDispose(() {
      _playbackStateSub?.cancel();
      _errorSub?.cancel();
      _reconnectSub?.cancel();
      _metadataPollTimer?.cancel();
    });

    // Restore saved playback context (last selected / default station) on launch
    Future.microtask(() => _restoreSavedPlaybackContext());

    return const PlayerState();
  }

  /// Restores saved station context and triggers automatic playback on startup if enabled
  Future<void> _restoreSavedPlaybackContext() async {
    // If the audio handler is already running, preserve its live station
    if (_audioHandler.currentStation != null) return;

    try {
      final cacheService = ref.read(cacheServiceProvider);
      final settings = ref.read(userSettingsProvider);

      Station? stationToRestore;

      // 1. Check cached last selected station first
      final cached = cacheService.getJson(
        CachePolicy.keyLastSelectedStation,
        allowExpired: true,
      );
      if (cached is Map<String, dynamic>) {
        stationToRestore = Station.fromJson(cached);
      }

      // 2. If user configured a specific default station, restore it
      if (settings.defaultStationId != null) {
        if (settings.defaultStationId == 6) {
          stationToRestore = const Station(
            id: 6,
            name: 'PulseCast Radio',
            description: 'Automated 24/7 internet radio streaming random music from Supabase Storage',
            genre: 'Mixed / Electronic',
            streamUrl: AppConfig.channel6StreamUrl,
            isActive: true,
          );
        } else if (ref.exists(stationsListProvider)) {
          final stations = ref.read(stationsListProvider).value;
          if (stations != null) {
            final matched = stations.where((s) => s.id == settings.defaultStationId).firstOrNull;
            if (matched != null) {
              stationToRestore = matched;
            }
          }
        }
      }

      if (stationToRestore != null && state.currentStation == null) {
        // Ensure effective production stream URL is used (replaces localhost)
        if (stationToRestore.id == 6 &&
            (stationToRestore.streamUrl.isEmpty || stationToRestore.streamUrl.contains('localhost'))) {
          stationToRestore = stationToRestore.copyWith(streamUrl: AppConfig.channel6StreamUrl);
        }

        // Populate context in idle status
        state = state.copyWith(
          currentStation: stationToRestore,
          status: RadioPlaybackStatus.idle,
        );

        // Autoplay if user enabled it and device is online
        final isOnline = ref.read(isOnlineProvider);
        if (settings.autoplayOnLaunch && isOnline) {
          await playStation(stationToRestore);
        }
      }
    } catch (_) {}
  }

  void _listenToAudioHandler() {
    _playbackStateSub = _audioHandler.playbackState.listen((playbackState) {
      final playing = playbackState.playing;
      final processingState = playbackState.processingState;

      RadioPlaybackStatus newStatus = state.status;
      if (state.status == RadioPlaybackStatus.reconnecting) {
        // Keep reconnecting status until AudioProcessingState.ready is reached
        if (processingState == AudioProcessingState.ready && playing) {
          newStatus = RadioPlaybackStatus.playing;
        }
      } else {
        switch (processingState) {
          case AudioProcessingState.idle:
            newStatus = RadioPlaybackStatus.idle;
            break;
          case AudioProcessingState.loading:
            newStatus = RadioPlaybackStatus.loading;
            break;
          case AudioProcessingState.buffering:
            newStatus = RadioPlaybackStatus.buffering;
            break;
          case AudioProcessingState.ready:
            newStatus = playing
                ? RadioPlaybackStatus.playing
                : RadioPlaybackStatus.paused;
            break;
          case AudioProcessingState.completed:
          case AudioProcessingState.error:
            newStatus = RadioPlaybackStatus.idle;
            break;
        }
      }

      final handlerStation = _audioHandler.currentStation;
      final shouldClearStation =
          handlerStation == null && processingState == AudioProcessingState.idle;
      state = state.copyWith(
        status: newStatus,
        currentStation: shouldClearStation ? null : (handlerStation ?? state.currentStation),
        clearStation: shouldClearStation,
      );
    });

    _errorSub = _audioHandler.errorStream.listen((errorMessage) {
      if (errorMessage != null) {
        state = state.copyWith(
          status: errorMessage.contains('Reconnecting')
              ? RadioPlaybackStatus.reconnecting
              : RadioPlaybackStatus.error,
          errorMessage: errorMessage,
        );
      } else if (state.hasError) {
        state = state.copyWith(clearError: true);
      }
    });

    _reconnectSub = _audioHandler.reconnectingStream.listen((isReconnecting) {
      if (isReconnecting) {
        state = state.copyWith(status: RadioPlaybackStatus.reconnecting);
      }
    });
  }

  /// Selects and plays a station stream with instant UI feedback, non-blocking metadata,
  /// low-latency stream handoff, and background state caching.
  Future<void> playStation(Station station) async {
    HapticFeedback.lightImpact();

    // 1. Check online connectivity
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      state = state.copyWith(
        currentStation: station,
        status: RadioPlaybackStatus.idle,
        errorMessage: 'Live radio requires internet connection. Reconnecting automatically when online.',
      );
      return;
    }

    // 2. Prevent repeated stream initialization for the same station while active or loading
    if (state.currentStation?.id == station.id) {
      if (state.isPlaying || state.isLoading || state.status == RadioPlaybackStatus.buffering) {
        // Already active or initializing: do not cancel/restart HTTP stream
        return;
      }
      if (state.status == RadioPlaybackStatus.paused) {
        // Paused: simply resume playback without re-requesting stream
        await play();
        return;
      }
    }

    // 3. Immediate visual state update (<16ms, zero-delay UI feedback)
    state = state.copyWith(
      currentStation: station,
      status: RadioPlaybackStatus.loading,
      clearError: true,
      nowPlaying: null,
    );

    // 3. Cache station context asynchronously in background (never blocks playback)
    unawaited(
      ref
          .read(cacheServiceProvider)
          .setJson(CachePolicy.keyLastSelectedStation, station.toJson())
          .catchError((_) => false),
    );

    // 4. Immediately trigger audio stream loading without awaiting metadata
    final audioPlayFuture = _audioHandler.playStation(station);

    // 5. Fetch NowPlaying metadata in parallel without delaying audio connection
    //    (Channel 6 uses direct Node.js `/api/now-playing` polling in channel6NowPlayingProvider)
    if (!station.isChannel6) {
      unawaited(
        _nowPlayingRepository
            .getNowPlaying(station.id)
            .then((NowPlayingInfo? metadata) {
              if (metadata != null && state.currentStation?.id == station.id) {
                state = state.copyWith(nowPlaying: metadata);
                _audioHandler.updateMetadata(metadata);
              }
            })
            .catchError((_) => null),
      );
    } else {
      _metadataPollTimer?.cancel();
    }

    await audioPlayFuture;

    // 6. Start periodic metadata refresh while playing (non-Channel 6 stations)
    if (!station.isChannel6) {
      _startMetadataPolling(station.id);
    }
  }

  void _startMetadataPolling(int stationId) {
    _metadataPollTimer?.cancel();
    final interval = ref.read(metadataPollingIntervalProvider);
    if (interval == null) return;

    _metadataPollTimer = Timer.periodic(interval, (_) async {
      if (state.currentStation?.id == stationId && state.isPlaying) {
        await refreshNowPlaying();
      }
    });
  }

  /// Refreshes current broadcast / song metadata
  Future<void> refreshNowPlaying() async {
    final currentStation = state.currentStation;
    if (currentStation == null || currentStation.isChannel6) return;

    try {
      final updated = await _nowPlayingRepository.getNowPlaying(currentStation.id);
      if (updated != null) {
        state = state.copyWith(nowPlaying: updated);
        _audioHandler.updateMetadata(updated);
      }
    } catch (_) {}
  }

  /// Toggles between Play and Pause
  Future<void> togglePlayPause() async {
    HapticFeedback.lightImpact();
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    HapticFeedback.lightImpact();
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      state = state.copyWith(
        errorMessage: 'Live radio requires internet connection. Reconnecting automatically when online.',
      );
      return;
    }

    if (state.currentStation != null) {
      await _audioHandler.play();
    }
  }

  Future<void> pause() async {
    HapticFeedback.lightImpact();
    await _audioHandler.pause();
  }

  double get volume => _audioHandler.volume;

  Future<void> setVolume(double value) async {
    await _audioHandler.setVolume(value);
  }

  Future<void> stop() async {
    _metadataPollTimer?.cancel();
    await _audioHandler.stop();
    state = state.copyWith(
      status: RadioPlaybackStatus.idle,
      clearStation: true,
      clearError: true,
    );
  }
}
