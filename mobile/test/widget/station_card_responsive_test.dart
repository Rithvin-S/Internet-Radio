import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulsecast/core/cache/cache_providers.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import 'package:pulsecast/features/stations/presentation/widgets/station_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const testWidths = [320.0, 360.0, 393.0, 412.0, 430.0];

  const radioParadise = Station(
    id: 1,
    name: 'Radio Paradise (Main Mix)',
    genre: 'Eclectic / Rock',
    description:
        'High-fidelity eclectic rock, indie, world and acoustic streaming live 24/7.',
    streamUrl: 'https://stream.radioparadise.com/mp3-128',
  );

  const nightwavePlaza = Station(
    id: 2,
    name: 'Nightwave Plaza',
    genre: 'Vaporwave / Electronic',
    description:
        '24/7 internet radio broadcast dedicated to vaporwave, future funk and ambient electronic soundscapes.',
    streamUrl: 'https://radio.plaza.one/mp3',
  );

  const somafmGroove = Station(
    id: 5,
    name: 'SomaFM Groove Salad',
    genre: 'Ambient / Downtempo',
    description: 'A nicely chilled plate of ambient/downtempo beats and grooves.',
    streamUrl: 'https://ice1.somafm.com/groovesalad-128-mp3',
  );

  const extremeStation = Station(
    id: 6, // id == 6 triggers isLocalFallback == true ('DEV' badge)
    name:
        'SomaFM Groove Salad Classic Ambient Downtempo Long Radio Name Broadcast Extra',
    genre: 'Vaporwave / Future Funk / Synthwave / Ambient Electronic / Chillout',
    description:
        'An exceptionally comprehensive 24/7 internet radio broadcast dedicated to vaporwave, future funk, synthwave, ambient downtempo, and chillout electronic soundscapes from around the entire globe.',
    streamUrl: 'http://localhost:8000/stream.mp3',
  );

  Widget buildTestableStationCard({
    required double width,
    required Station station,
    required bool isSelected,
    required bool isPlaying,
    required bool isLoading,
    double textScale = 1.0,
    VoidCallback? onSelect,
    VoidCallback? onTogglePlay,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: TextScaler.linear(textScale),
                ),
                child: StationCard(
                  station: station,
                  isSelected: isSelected,
                  isPlaying: isPlaying,
                  isLoading: isLoading,
                  onSelect: onSelect ?? () {},
                  onTogglePlay: onTogglePlay ?? () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('StationCard Responsive Layout Tests (Zero RenderFlex Overflow)', () {
    for (final width in testWidths) {
      testWidgets('Radio Paradise selected & STREAMING at width: ${width}px (S24 Fix)',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableStationCard(
            width: width,
            station: radioParadise,
            isSelected: true,
            isPlaying: true,
            isLoading: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Radio Paradise (Main Mix)'), findsOneWidget);
        expect(find.text('STREAMING'), findsOneWidget);
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'Radio Paradise with Samsung S24 1.25x font scale at width: ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableStationCard(
            width: width,
            station: radioParadise,
            isSelected: true,
            isPlaying: true,
            isLoading: false,
            textScale: 1.25,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Radio Paradise (Main Mix)'), findsOneWidget);
        expect(find.text('STREAMING'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Nightwave Plaza selected & STREAMING at width: ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableStationCard(
            width: width,
            station: nightwavePlaza,
            isSelected: true,
            isPlaying: true,
            isLoading: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nightwave Plaza'), findsOneWidget);
        expect(find.text('STREAMING'), findsOneWidget);
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('SomaFM Groove Salad unselected at width: ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableStationCard(
            width: width,
            station: somafmGroove,
            isSelected: false,
            isPlaying: false,
            isLoading: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('SomaFM Groove Salad'), findsOneWidget);
        expect(find.text('Ambient / Downtempo'), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'Extreme long title, genre, and description with DEV badge at width: ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableStationCard(
            width: width,
            station: extremeStation,
            isSelected: true,
            isPlaying: true,
            isLoading: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('DEV'), findsOneWidget);
        expect(find.text('STREAMING'), findsOneWidget);
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Selected, paused (READY state) at width: ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableStationCard(
            width: width,
            station: nightwavePlaza,
            isSelected: true,
            isPlaying: false,
            isLoading: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('READY'), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Selected and loading state at width: ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableStationCard(
            width: width,
            station: nightwavePlaza,
            isSelected: true,
            isPlaying: false,
            isLoading: true,
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'Tapping onSelect and onTogglePlay triggers respective callbacks',
        (tester) async {
      bool selected = false;
      bool playToggled = false;

      await tester.pumpWidget(
        buildTestableStationCard(
          width: 360,
          station: nightwavePlaza,
          isSelected: false,
          isPlaying: false,
          isLoading: false,
          onSelect: () => selected = true,
          onTogglePlay: () => playToggled = true,
        ),
      );
      await tester.pumpAndSettle();

      // Tap on station title/card area
      await tester.tap(find.text('Nightwave Plaza'));
      await tester.pump();
      expect(selected, isTrue);

      // Tap on play button
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(playToggled, isTrue);
    });
  });
}
