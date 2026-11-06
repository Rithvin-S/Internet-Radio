import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/features/admin/admin_dashboard_screen.dart';
import 'package:pulsecast/features/admin/domain/models/admin_dashboard_stats.dart';
import 'package:pulsecast/features/admin/domain/models/admin_song.dart';
import 'package:pulsecast/features/admin/domain/models/admin_song_stats.dart';
import 'package:pulsecast/features/admin/presentation/providers/admin_providers.dart';
import 'package:pulsecast/features/admin/presentation/screens/admin_songs_screen.dart';
import 'package:pulsecast/features/admin/presentation/screens/admin_stations_screen.dart';
import 'package:pulsecast/features/auth/domain/models/user.dart';
import 'package:pulsecast/features/auth/domain/models/user_role.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_providers.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_state.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import '../unit/routing/role_based_routing_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final adminUser = User(
    id: 1,
    name: 'Admin User',
    email: 'admin@pulsecast.com',
    role: UserRole.admin,
  );

  final testDashboardStats = AdminDashboardStats(
    songStats: const AdminSongStats(
      totalSongs: 12,
      activeSongs: 11,
      totalStorageBytes: 104857600,
      totalDurationSeconds: 3600,
    ),
    totalStations: 5,
    activeStations: 5,
    totalSchedules: 4,
    publishedSchedules: 3,
    serverStatus: 'online',
    lastChecked: DateTime(2026, 11, 2, 14, 0),
  );

  final testSongs = [
    const AdminSong(
      id: '1a3825f2-1b65-4615-9f03-c42722d73551',
      title: 'Teardrop',
      artist: 'Massive Attack',
      album: 'Mezzanine',
      duration: '05:30',
      durationSeconds: 330,
      fileSizeBytes: 7890123,
      storageBucket: 'pulsecast-music-library',
      storagePath: 'library/.../teardrop.mp3',
      isActive: true,
    ),
    const AdminSong(
      id: '2b4936f3-2c76-5726-0e14-d53833e84662',
      title: 'Karma Police',
      artist: 'Radiohead',
      album: 'OK Computer',
      duration: '04:24',
      durationSeconds: 264,
      fileSizeBytes: 6543210,
      storageBucket: 'pulsecast-music-library',
      storagePath: 'library/.../karmapolice.mp3',
      isActive: false,
    ),
  ];

  final testStations = [
    const Station(
      id: 1,
      name: 'Radio Paradise',
      streamUrl: 'https://stream.radioparadise.com/mp3-128',
      isActive: true,
    ),
    const Station(
      id: 2,
      name: 'Nightwave Plaza',
      streamUrl: 'https://radio.plaza.one/mp3',
      isActive: false,
    ),
  ];

  testWidgets('AdminDashboardScreen renders live stats, health status, and module cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            () => FakeAuthNotifier(AuthState.authenticated(adminUser)),
          ),
          adminDashboardStatsProvider.overrideWith(
            (ref) => Future.value(testDashboardStats),
          ),
        ],
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Admin Portal banner
    expect(find.text('Administrator Portal'), findsOneWidget);
    expect(find.textContaining('Signed in as Admin User'), findsOneWidget);

    // Verify System Overview Stat Cards
    expect(find.text('Total Songs'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Storage Used'), findsOneWidget);
    expect(find.text('100.0 MB'), findsOneWidget);
    expect(find.text('Broadcast Stations'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Program Schedules'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    // Verify Gateway Health
    expect(find.textContaining('Backend API Gateway: ONLINE'), findsOneWidget);

    // Verify Module Cards
    expect(find.text('Station Management'), findsOneWidget);
    expect(find.text('Music Library (Supabase)'), findsOneWidget);
    expect(find.text('Broadcast Schedules'), findsOneWidget);
  });

  testWidgets('AdminSongsScreen renders summary bar, search, and song cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminSongsListProvider.overrideWith((ref) => Future.value(testSongs)),
          adminSongStatsProvider.overrideWith(
            (ref) => Future.value(testDashboardStats.songStats!),
          ),
        ],
        child: const MaterialApp(
          home: AdminSongsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify App Bar & Summary Bar
    expect(find.text('Music Library'), findsOneWidget);
    expect(find.text('Upload Song'), findsOneWidget);

    // Verify Songs and Status Badges
    expect(find.text('Teardrop'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Karma Police'), findsOneWidget);
    expect(find.text('ARCHIVED'), findsOneWidget);
  });

  testWidgets('AdminStationsScreen renders stations with active switches', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminStationsListProvider.overrideWith((ref) => Future.value(testStations)),
        ],
        child: const MaterialApp(
          home: AdminStationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Station Management'), findsOneWidget);
    expect(find.text('New Station'), findsOneWidget);
    expect(find.text('Radio Paradise'), findsOneWidget);
    expect(find.text('Nightwave Plaza'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
  });
}
