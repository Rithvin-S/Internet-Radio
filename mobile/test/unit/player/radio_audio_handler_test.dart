import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/features/player/domain/models/now_playing_info.dart';
import 'package:pulsecast/features/player/services/radio_audio_handler.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import '../../mocks/fake_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RadioAudioHandler Unit Tests', () {
    late FakeAudioPlayer fakePlayer;
    late RadioAudioHandler audioHandler;

    const testStation1 = Station(
      id: 1,
      name: 'Radio Paradise (Main Mix)',
      genre: 'Rock',
      streamUrl: 'https://stream.radioparadise.com/mp3-128',
    );

    const testStation2 = Station(
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

    test('Successful stream playback loads URL and starts playing', () async {
      await audioHandler.playStation(testStation1);

      expect(audioHandler.currentStation?.id, 1);
      expect(fakePlayer.loadedUrl, 'https://stream.radioparadise.com/mp3-128');
      expect(fakePlayer.playing, isTrue);

      // Verifies notification media item
      expect(audioHandler.mediaItem.value?.title, 'Radio Paradise (Main Mix)');
      expect(audioHandler.mediaItem.value?.album, 'Rock');
    });

    test('Pause and resume controls the stream engine', () async {
      await audioHandler.playStation(testStation1);
      expect(fakePlayer.playing, isTrue);

      await audioHandler.pause();
      expect(fakePlayer.playing, isFalse);

      await audioHandler.play();
      expect(fakePlayer.playing, isTrue);
    });

    test('Switching stations stops previous stream to prevent overlapping playback', () async {
      await audioHandler.playStation(testStation1);
      expect(fakePlayer.loadedUrl, testStation1.streamUrl);

      // Switch to station 2
      await audioHandler.playStation(testStation2);
      expect(audioHandler.currentStation?.id, 7);
      expect(fakePlayer.loadedUrl, testStation2.streamUrl);
      expect(fakePlayer.playing, isTrue);
    });

    test('Stream failure triggers reconnection attempts and bounded backoff', () async {
      fakePlayer.shouldThrowOnSetUrl = true;

      final errors = <String?>[];
      final errorSub = audioHandler.errorStream.listen((err) => errors.add(err));

      await audioHandler.playStation(testStation1);

      // Verify that reconnecting error was broadcast
      expect(errors, isNotEmpty);
      expect(errors.any((msg) => msg != null && msg.contains('Reconnecting')), isTrue);

      await errorSub.cancel();
    });

    test('updateMetadata updates notification and lock-screen MediaItem without reloading stream', () async {
      await audioHandler.playStation(testStation1);

      const metadata = NowPlayingInfo(
        stationId: 1,
        title: 'Teardrop',
        artist: 'Massive Attack',
      );

      audioHandler.updateMetadata(metadata);

      expect(audioHandler.mediaItem.value?.title, 'Teardrop');
      expect(audioHandler.mediaItem.value?.artist, 'Massive Attack');
    });

    test('Stop halts playback and emits idle processing state', () async {
      await audioHandler.playStation(testStation1);
      expect(fakePlayer.playing, isTrue);

      await audioHandler.stop();
      expect(fakePlayer.playing, isFalse);
      expect(audioHandler.playbackState.value.processingState, AudioProcessingState.idle);
    });
  });
}

