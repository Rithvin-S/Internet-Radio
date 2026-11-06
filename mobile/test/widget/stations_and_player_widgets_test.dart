import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/features/player/data/now_playing_repository.dart';
import 'package:pulsecast/features/player/domain/models/now_playing_info.dart';
import 'package:pulsecast/features/player/presentation/providers/player_providers.dart';
import 'package:pulsecast/features/player/presentation/providers/player_state.dart';
import 'package:pulsecast/features/player/presentation/screens/full_player_screen.dart';
import 'package:pulsecast/features/player/presentation/widgets/mini_player.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import 'package:pulsecast/features/stations/presentation/providers/stations_provider.dart';
import 'package:pulsecast/features/stations/presentation/screens/stations_screen.dart';
import '../mocks/fake_audio_player.dart';
import 'package:pulsecast/features/player/services/radio_audio_handler.dart';

class FakeNowPlayingRepository implements INowPlayingRepository {
  @override
  Future<NowPlayingInfo?> getNowPlaying(int stationId) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockStations = [
    Station(
      id: 7,
      name: 'PulseCast Radio (AWS)',
      genre: 'Mixed',
      description: 'Official EC2 Icecast live broadcast',
      streamUrl: 'https://pulsecast.duckdns.org/pulsecast.mp3',
    ),
    Station(
      id: 1,
      name: 'Radio Paradise (Main Mix)',
      genre: 'Rock',
      description: 'Eclectic rock broadcast',
      streamUrl: 'https://stream.radioparadise.com/mp3-128',
    ),
  ];

  group('StationsScreen & Player Widgets Tests', () {
    testWidgets('StationsScreen renders station cards from provider', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stationsListProvider.overrideWith((ref) => Future.value(mockStations)),
          ],
          child: const MaterialApp(
            home: StationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Radio Stations'), findsOneWidget);
      expect(find.text('PulseCast Radio (AWS)'), findsOneWidget);
      expect(find.text('Radio Paradise (Main Mix)'), findsOneWidget);
      expect(find.text('Official EC2 Icecast live broadcast'), findsOneWidget);
    });

    testWidgets('MiniPlayerWidget is hidden when no station is active', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: MiniPlayerWidget(),
            ),
          ),
        ),
      );

      // Verify empty widget / hidden
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('MiniPlayerWidget renders and opens FullPlayerScreen when station is active', (tester) async {
      final fakePlayer = FakeAudioPlayer();
      final audioHandler = RadioAudioHandler(player: fakePlayer);

      final container = ProviderContainer(
        overrides: [
          radioAudioHandlerProvider.overrideWithValue(audioHandler),
          stationsListProvider.overrideWith((ref) => Future.value(mockStations)),
          nowPlayingRepositoryProvider.overrideWithValue(FakeNowPlayingRepository()),
          metadataPollingIntervalProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              bottomNavigationBar: MiniPlayerWidget(),
            ),
          ),
        ),
      );

      // Trigger station playback
      await container.read(playerNotifierProvider.notifier).playStation(mockStations[0]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify mini player displays station name
      expect(find.text('PulseCast Radio (AWS)'), findsOneWidget);

      // Tap mini player to open FullPlayerScreen
      await tester.tap(find.byType(MiniPlayerWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify FullPlayerScreen modal is presented
      expect(find.byType(FullPlayerScreen), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Connected • High Fidelity Stream'), findsOneWidget);

      await audioHandler.dispose();
    });

    testWidgets('FullPlayerScreen displays up-next track queue when metadata is available', (tester) async {
      final fakePlayer = FakeAudioPlayer();
      final audioHandler = RadioAudioHandler(player: fakePlayer);

      final container = ProviderContainer(
        overrides: [
          radioAudioHandlerProvider.overrideWithValue(audioHandler),
          stationsListProvider.overrideWith((ref) => Future.value(mockStations)),
          nowPlayingRepositoryProvider.overrideWithValue(FakeNowPlayingRepository()),
          metadataPollingIntervalProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: FullPlayerScreen(),
            ),
          ),
        ),
      );

      // Set player state with upcoming tracks
      container.read(playerNotifierProvider.notifier).state = PlayerState(
        currentStation: mockStations[1],
        status: RadioPlaybackStatus.playing,
        nowPlaying: const NowPlayingInfo(
          stationId: 1,
          title: 'Teardrop',
          artist: 'Massive Attack',
          upNext: [
            QueuedTrack(id: 2, title: 'Karma Police', artist: 'Radiohead'),
            QueuedTrack(id: 3, title: 'Drive', artist: 'R.E.M.'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Radio Paradise (Main Mix)'), findsOneWidget);
      expect(find.text('Teardrop'), findsOneWidget);
      expect(find.text('Massive Attack'), findsOneWidget);
      expect(find.text('Karma Police'), findsOneWidget);
      expect(find.text('Radiohead'), findsOneWidget);
      expect(find.text('Drive'), findsOneWidget);

      await audioHandler.dispose();
    });
  });
}

