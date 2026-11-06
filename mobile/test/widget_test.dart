import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/features/player/presentation/providers/player_providers.dart';
import 'package:pulsecast/features/player/services/radio_audio_handler.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import 'package:pulsecast/features/stations/presentation/providers/stations_provider.dart';
import 'package:pulsecast/main.dart';
import 'mocks/fake_audio_player.dart';

void main() {
  testWidgets('PulseCast app smoke and navigation shell test', (WidgetTester tester) async {
    final fakePlayer = FakeAudioPlayer();
    final audioHandler = RadioAudioHandler(player: fakePlayer);

    const testStations = [
      Station(
        id: 7,
        name: 'PulseCast Radio (AWS)',
        genre: 'Mixed',
        streamUrl: 'https://pulsecast.duckdns.org/pulsecast.mp3',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          radioAudioHandlerProvider.overrideWithValue(audioHandler),
          stationsListProvider.overrideWith((ref) => Future.value(testStations)),
          metadataPollingIntervalProvider.overrideWithValue(null),
        ],
        child: const PulseCastApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify brand headers and elements are rendered
    expect(find.text('PULSE'), findsOneWidget);
    expect(find.text('CAST'), findsOneWidget);
    expect(find.text('Switch Stations'), findsOneWidget);

    await audioHandler.dispose();
  });
}
