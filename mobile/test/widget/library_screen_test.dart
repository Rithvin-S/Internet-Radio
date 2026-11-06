import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/features/library/domain/models/listener_track.dart';
import 'package:pulsecast/features/library/library_screen.dart';
import 'package:pulsecast/features/library/presentation/providers/listener_library_providers.dart';
import 'package:pulsecast/features/player/presentation/providers/player_providers.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import 'package:pulsecast/features/stations/presentation/providers/stations_provider.dart';
import 'package:pulsecast/features/player/services/radio_audio_handler.dart';
import '../mocks/fake_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testStations = [
    const Station(
      id: 1,
      name: 'Radio Paradise',
      streamUrl: 'https://stream.radioparadise.com/mp3-128',
    ),
    const Station(
      id: 2,
      name: 'Nightwave Plaza',
      streamUrl: 'https://radio.plaza.one/mp3',
    ),
  ];

  final testTracks = [
    const ListenerTrack(
      id: 1,
      stationId: 1,
      stationName: 'Radio Paradise',
      title: 'Teardrop',
      artist: 'Massive Attack',
      album: 'Mezzanine',
      duration: '05:30',
      status: 'playing',
    ),
    const ListenerTrack(
      id: 2,
      stationId: 1,
      stationName: 'Radio Paradise',
      title: 'Karma Police',
      artist: 'Radiohead',
      album: 'OK Computer',
      duration: '04:24',
      status: 'queued',
    ),
  ];

  testWidgets('LibraryScreen renders search, chips, and track list with live indicator', (tester) async {
    final fakeAudioPlayer = FakeAudioPlayer();
    final fakeAudioHandler = RadioAudioHandler(player: fakeAudioPlayer);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stationsListProvider.overrideWith((ref) => Future.value(testStations)),
          listenerTracksProvider.overrideWith((ref) => Future.value(testTracks)),
          radioAudioHandlerProvider.overrideWithValue(fakeAudioHandler),
          metadataPollingIntervalProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify search field
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search tracks, artists, stations...'), findsOneWidget);

    // Verify filter chips
    expect(find.text('All Stations'), findsOneWidget);
    expect(find.text('All Tracks'), findsOneWidget);
    expect(find.text('Playing Now'), findsOneWidget);

    // Verify track cards
    expect(find.text('Teardrop'), findsOneWidget);
    expect(find.text('Massive Attack • Mezzanine'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Karma Police'), findsOneWidget);

    // Tap track card to open TrackDetailModal
    await tester.tap(find.text('Teardrop'));
    await tester.pumpAndSettle();

    // Verify bottom sheet content
    expect(find.text('Broadcast Station'), findsOneWidget);
    expect(find.text('Track Duration'), findsOneWidget);
    expect(find.text('Tune In to Radio Paradise'), findsOneWidget);
  });
}
