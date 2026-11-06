import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/features/auth/domain/models/auth_response.dart';
import 'package:pulsecast/features/auth/domain/models/user.dart';
import 'package:pulsecast/features/auth/domain/models/user_role.dart';
import 'package:pulsecast/features/auth/data/auth_repository.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_notifier.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_providers.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_state.dart';
import 'package:pulsecast/features/player/presentation/providers/player_providers.dart';
import 'package:pulsecast/features/player/services/radio_audio_handler.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import 'package:pulsecast/features/admin/presentation/providers/admin_providers.dart';
import 'package:pulsecast/features/admin/domain/models/admin_dashboard_stats.dart';
import 'package:pulsecast/features/admin/domain/models/admin_song_stats.dart';
import 'package:pulsecast/features/admin/domain/models/admin_song.dart';
import 'package:pulsecast/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:pulsecast/features/stations/presentation/providers/stations_provider.dart';
import 'package:pulsecast/routing/app_router.dart';
import 'package:pulsecast/routing/route_names.dart';
import '../../mocks/fake_audio_player.dart';

class FakeAuthRepository implements IAuthRepository {
  User? initialUser;

  FakeAuthRepository({this.initialUser});

  @override
  Future<User?> restoreSession() async => initialUser;

  @override
  Future<AuthResponse> login({required String email, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthResponse> register({required String name, required String email, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<User?> getMe() async => initialUser;
}

class FakeAuthNotifier extends AuthNotifier {
  final AuthState _fixedState;

  FakeAuthNotifier(this._fixedState);

  @override
  AuthState build() => _fixedState;
}

class FakeFavoritesNotifier extends FavoritesNotifier {
  @override
  FavoritesState build() => const FavoritesState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakePlayer = FakeAudioPlayer();
  final testAudioHandler = RadioAudioHandler(player: fakePlayer);
  const testStations = <Station>[
    Station(
      id: 7,
      name: 'PulseCast Radio (AWS)',
      genre: 'Mixed',
      streamUrl: 'https://pulsecast.duckdns.org/pulsecast.mp3',
    ),
  ];

  const testAdminSongs = <AdminSong>[
    AdminSong(
      id: 'song-uuid-1',
      title: 'Neon Dreams',
      artist: 'SynthWave Artist',
      album: 'Retro Future',
      durationSeconds: 180,
      storageBucket: 'pulsecast-music-library',
      storagePath: 'songs/neon_dreams.mp3',
      isActive: true,
    ),
  ];

  group('Role-Based Access Control and Routing Tests', () {
    testWidgets('Unauthenticated guest attempting to access /admin is redirected to /login with redirect query', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeAuthNotifier(const AuthState.unauthenticated()),
            ),
            radioAudioHandlerProvider.overrideWithValue(testAudioHandler),
            stationsListProvider.overrideWith((ref) => Future.value(testStations)),
            metadataPollingIntervalProvider.overrideWithValue(null),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Attempt to navigate to protected admin route
      final BuildContext context = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(context);
      final router = container.read(appRouterProvider);

      router.go(RouteNames.admin);
      await tester.pumpAndSettle();

      // Verifies redirected to login screen with redirect query param
      expect(find.text('PULSECAST'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('Authenticated Listener attempting to access /admin is denied and redirected to /settings', (tester) async {
      final listenerUser = User(
        id: 2,
        name: 'Listener User',
        email: 'listener@pulsecast.com',
        role: UserRole.listener,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeAuthNotifier(AuthState.authenticated(listenerUser)),
            ),
            radioAudioHandlerProvider.overrideWithValue(testAudioHandler),
            stationsListProvider.overrideWith((ref) => Future.value(testStations)),
            metadataPollingIntervalProvider.overrideWithValue(null),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(context);
      final router = container.read(appRouterProvider);

      // Attempt to navigate to admin route
      router.go(RouteNames.admin);
      await tester.pumpAndSettle();

      // Verifies blocked from Admin and redirected to Profile
      expect(find.text('LISTENER'), findsWidgets);
      expect(find.text('Listener User'), findsOneWidget);
    });

    testWidgets('Authenticated Administrator has full access to Admin Portal', (tester) async {
      final adminUser = User(
        id: 1,
        name: 'Admin User',
        email: 'admin@pulsecast.com',
        role: UserRole.admin,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeAuthNotifier(AuthState.authenticated(adminUser)),
            ),
            radioAudioHandlerProvider.overrideWithValue(testAudioHandler),
            stationsListProvider.overrideWith((ref) => Future.value(testStations)),
            metadataPollingIntervalProvider.overrideWithValue(null),
            adminDashboardStatsProvider.overrideWith(
              (ref) => Future.value(
                AdminDashboardStats(
                  songStats: const AdminSongStats(totalSongs: 7, activeSongs: 7),
                  totalStations: 5,
                  activeStations: 5,
                  totalSchedules: 3,
                  publishedSchedules: 2,
                  lastChecked: DateTime.now(),
                ),
              ),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(context);
      final router = container.read(appRouterProvider);

      router.go(RouteNames.admin);
      await tester.pumpAndSettle();

      // Verifies Admin Portal is rendered
      expect(find.text('Administrator Portal'), findsOneWidget);
      expect(find.text('Station Management'), findsOneWidget);
      expect(find.text('Music Library (Supabase)'), findsOneWidget);
    });
  });

  group('Dynamic Role-Based AppShell Navigation Tests', () {
    testWidgets('Logged-out state (first launch) displays exactly two tabs: Radio and Sign In', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeAuthNotifier(const AuthState.unauthenticated()),
            ),
            radioAudioHandlerProvider.overrideWithValue(testAudioHandler),
            stationsListProvider.overrideWith((ref) => Future.value(testStations)),
            metadataPollingIntervalProvider.overrideWithValue(null),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check BottomNavigationBar items
      final navBarFinder = find.byType(BottomNavigationBar);
      expect(navBarFinder, findsOneWidget);
      final navBar = tester.widget<BottomNavigationBar>(navBarFinder);
      expect(navBar.items.length, 2);
      expect(navBar.items[0].label, 'Radio');
      expect(navBar.items[1].label, 'Sign In');

      final labels = navBar.items.map((i) => i.label).toSet();
      expect(labels.contains('Favourites'), isFalse);
      expect(labels.contains('Library'), isFalse);
      expect(labels.contains('Stations'), isFalse);

      // Verify Radio tab is selected and station is visible without requiring login
      expect(find.text('PulseCast Radio (AWS)'), findsWidgets);

      // Switch to Sign In tab
      await tester.tap(find.byIcon(Icons.login_rounded));
      await tester.pumpAndSettle();

      // Verify Sign In screen is rendered
      expect(find.text('PULSECAST'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email and password

      // Switch back to Radio tab
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byIcon(Icons.radio_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PulseCast Radio (AWS)'), findsWidgets);
    });

    testWidgets('Signed-in normal user (listener) displays exactly three tabs: Radio, Favourites, Settings', (tester) async {
      final listenerUser = User(
        id: 2,
        name: 'Listener User',
        email: 'listener@pulsecast.com',
        role: UserRole.listener,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeAuthNotifier(AuthState.authenticated(listenerUser)),
            ),
            favoritesProvider.overrideWith(() => FakeFavoritesNotifier()),
            radioAudioHandlerProvider.overrideWithValue(testAudioHandler),
            stationsListProvider.overrideWith((ref) => Future.value(testStations)),
            metadataPollingIntervalProvider.overrideWithValue(null),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check BottomNavigationBar items
      final navBar = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(navBar.items.length, 3);
      expect(navBar.items[0].label, 'Radio');
      expect(navBar.items[1].label, 'Favourites');
      expect(navBar.items[2].label, 'Settings');

      final labels = navBar.items.map((i) => i.label).toSet();
      expect(labels.contains('Sign In'), isFalse);
      expect(labels.contains('Library'), isFalse);
      expect(labels.contains('Stations'), isFalse);

      // Switch to Favourites tab
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Favorites'), findsOneWidget);

      // Switch to Settings tab
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Settings & Preferences'), findsOneWidget);
      expect(find.text('LISTENER'), findsWidgets);
      expect(find.text('Listener User'), findsOneWidget);
    });

    testWidgets('Authenticated Administrator displays exactly four tabs: Radio, Library, Stations, Settings', (tester) async {
      final adminUser = User(
        id: 1,
        name: 'Admin User',
        email: 'admin@pulsecast.com',
        role: UserRole.admin,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeAuthNotifier(AuthState.authenticated(adminUser)),
            ),
            radioAudioHandlerProvider.overrideWithValue(testAudioHandler),
            stationsListProvider.overrideWith((ref) => Future.value(testStations)),
            metadataPollingIntervalProvider.overrideWithValue(null),
            adminSongsListProvider.overrideWith((ref) => Future.value(testAdminSongs)),
            adminSongStatsProvider.overrideWith(
              (ref) => Future.value(const AdminSongStats(totalSongs: 1, activeSongs: 1)),
            ),
            adminStationsListProvider.overrideWith((ref) => Future.value(testStations)),
            adminSchedulesListProvider.overrideWith((ref) => Future.value([])),
            adminDashboardStatsProvider.overrideWith(
              (ref) => Future.value(
                AdminDashboardStats(
                  songStats: const AdminSongStats(totalSongs: 1, activeSongs: 1),
                  totalStations: 1,
                  activeStations: 1,
                  totalSchedules: 0,
                  publishedSchedules: 0,
                  lastChecked: DateTime.now(),
                ),
              ),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check BottomNavigationBar items
      final navBar = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(navBar.items.length, 4);
      expect(navBar.items[0].label, 'Radio');
      expect(navBar.items[1].label, 'Library');
      expect(navBar.items[2].label, 'Stations');
      expect(navBar.items[3].label, 'Settings');

      final labels = navBar.items.map((i) => i.label).toSet();
      expect(labels.contains('Sign In'), isFalse);
      expect(labels.contains('Favourites'), isFalse);

      // Switch to Library tab (Admin Song Management)
      await tester.tap(find.byIcon(Icons.library_music_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Music Library'), findsOneWidget);

      // Switch to Stations tab (Unified Portal with Stations & Schedules tabs)
      await tester.tap(find.byIcon(Icons.cell_tower_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Stations & Schedules'), findsOneWidget);
      expect(find.text('Schedules'), findsOneWidget);

      // Switch to Settings tab
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();
      expect(find.text('ADMIN'), findsWidgets);
      expect(find.text('Admin User'), findsOneWidget);
    });
  });
}
