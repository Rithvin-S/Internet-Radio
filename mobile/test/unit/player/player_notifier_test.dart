import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/core/connectivity/connectivity_providers.dart';
import 'package:pulsecast/features/player/data/now_playing_repository.dart';
import 'package:pulsecast/features/player/domain/models/now_playing_info.dart';
import 'package:pulsecast/features/player/presentation/providers/player_providers.dart';
import 'package:pulsecast/features/player/presentation/providers/player_state.dart';
import 'package:pulsecast/features/player/services/radio_audio_handler.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import '../../mocks/fake_audio_player.dart';

class FakeNowPlayingRepository implements INowPlayingRepository {
  @override
  Future<NowPlayingInfo?> getNowPlaying(int stationId) async {
    return NowPlayingInfo(
      stationId: stationId,
      title: 'Current Song',
      artist: 'Current Artist',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerNotifier State Synchronization Tests', () {
    late FakeAudioPlayer fakePlayer;
    late RadioAudioHandler audioHandler;

    const testStation = Station(
      id: 7,
      name: 'PulseCast Radio (AWS)',
      genre: 'Mixed',
      streamUrl: 'https://pulsecast.duckdns.org/pulsecast.mp3',
    );

    setUp(() {
      fakePlayer = FakeAudioPlayer();
      audioHandler = RadioAudioHandler(player: fakePlayer);
    });

    tearDown(() async {
      await audioHandler.dispose();
    });

    test('Selecting a station updates currentStation, fetches metadata, and streams audio', () async {
      final container = ProviderContainer(
        overrides: [
          radioAudioHandlerProvider.overrideWithValue(audioHandler),
          nowPlayingRepositoryProvider.overrideWithValue(FakeNowPlayingRepository()),
          metadataPollingIntervalProvider.overrideWithValue(null),
          isOnlineProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(playerNotifierProvider.notifier);
      await notifier.playStation(testStation);
      await pumpEventQueue();

      final state = container.read(playerNotifierProvider);
      expect(state.currentStation?.id, 7);
      expect(state.nowPlaying?.title, 'Current Song');
      expect(state.nowPlaying?.artist, 'Current Artist');
      expect(state.isPlaying, isTrue);
    });

    test('togglePlayPause toggles stream between playing and paused', () async {
      final container = ProviderContainer(
        overrides: [
          radioAudioHandlerProvider.overrideWithValue(audioHandler),
          nowPlayingRepositoryProvider.overrideWithValue(FakeNowPlayingRepository()),
          metadataPollingIntervalProvider.overrideWithValue(null),
          isOnlineProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(playerNotifierProvider.notifier);
      await notifier.playStation(testStation);
      await pumpEventQueue();
      expect(container.read(playerNotifierProvider).isPlaying, isTrue);

      await notifier.togglePlayPause();
      await pumpEventQueue();
      expect(container.read(playerNotifierProvider).isPaused, isTrue);

      await notifier.togglePlayPause();
      await pumpEventQueue();
      expect(container.read(playerNotifierProvider).isPlaying, isTrue);
    });

    test('Stop halts audio and resets player state to idle', () async {
      final container = ProviderContainer(
        overrides: [
          radioAudioHandlerProvider.overrideWithValue(audioHandler),
          nowPlayingRepositoryProvider.overrideWithValue(FakeNowPlayingRepository()),
          metadataPollingIntervalProvider.overrideWithValue(null),
          isOnlineProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(playerNotifierProvider.notifier);
      await notifier.playStation(testStation);
      await pumpEventQueue();
      expect(container.read(playerNotifierProvider).hasActiveStation, isTrue);

      await notifier.stop();
      await pumpEventQueue();
      final state = container.read(playerNotifierProvider);
      expect(state.status, RadioPlaybackStatus.idle);
      expect(state.currentStation, isNull);
    });

    test('Fast stream startup: playStation starts audio immediately without waiting for slow metadata API', () async {
      final completer = Completer<NowPlayingInfo?>();

      final slowRepo = _SlowNowPlayingRepository(completer.future);

      final container = ProviderContainer(
        overrides: [
          radioAudioHandlerProvider.overrideWithValue(audioHandler),
          nowPlayingRepositoryProvider.overrideWithValue(slowRepo),
          metadataPollingIntervalProvider.overrideWithValue(null),
          isOnlineProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(playerNotifierProvider.notifier);

      // Call playStation: it should NOT block on metadata
      await notifier.playStation(testStation);
      await pumpEventQueue();

      // Verify audio has already started streaming immediately
      final immediateState = container.read(playerNotifierProvider);
      expect(immediateState.currentStation?.id, 7);
      expect(immediateState.isPlaying, isTrue);
      expect(fakePlayer.playing, isTrue);
      // Metadata is still pending from the slow network API
      expect(immediateState.nowPlaying, isNull);

      // Now complete the delayed metadata
      completer.complete(const NowPlayingInfo(
        stationId: 7,
        title: 'Delayed Track',
        artist: 'Delayed Artist',
      ));
      await pumpEventQueue();

      // State is asynchronously updated when metadata arrives
      final updatedState = container.read(playerNotifierProvider);
      expect(updatedState.nowPlaying?.title, 'Delayed Track');
      expect(updatedState.nowPlaying?.artist, 'Delayed Artist');
    });
  });
}

class _SlowNowPlayingRepository implements INowPlayingRepository {
  final Future<NowPlayingInfo?> _future;
  _SlowNowPlayingRepository(this._future);

  @override
  Future<NowPlayingInfo?> getNowPlaying(int stationId) => _future;
}

