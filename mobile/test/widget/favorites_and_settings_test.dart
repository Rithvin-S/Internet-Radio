import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulsecast/core/cache/cache_providers.dart';
import 'package:pulsecast/core/theme/app_theme.dart';
import 'package:pulsecast/features/auth/domain/models/user.dart';
import 'package:pulsecast/features/auth/domain/models/user_role.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_notifier.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_providers.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_state.dart';
import 'package:pulsecast/features/favourites/favourites_screen.dart';
import 'package:pulsecast/features/settings/presentation/screens/settings_screen.dart';
import 'package:pulsecast/features/stations/presentation/providers/stations_provider.dart';

class FakeAuthNotifier extends AuthNotifier {
  final AuthState _fixedState;

  FakeAuthNotifier(this._fixedState);

  @override
  AuthState build() => _fixedState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Favorites & Settings Widget Tests', () {
    testWidgets('FavouritesScreen renders tabs and empty states with action CTAs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: FavouritesScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Screen title and Tab items
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Stations (0)'), findsOneWidget);
      expect(find.text('Songs (0)'), findsOneWidget);

      // Verify Empty Stations state
      expect(find.text('No Favorite Stations Yet'), findsOneWidget);
      expect(find.text('Explore Stations'), findsOneWidget);

      // Switch to Songs Tab
      await tester.tap(find.text('Songs (0)'));
      await tester.pumpAndSettle();

      // Verify Empty Songs state
      expect(find.text('No Favorite Songs Yet'), findsOneWidget);
      expect(find.text('Browse Library'), findsOneWidget);
    });

    testWidgets('SettingsScreen renders configuration sections and controls', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            stationsListProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify AppBar
      expect(find.text('Settings & Preferences'), findsOneWidget);

      // Verify Sections
      expect(find.text('NETWORK & SYNCHRONIZATION'), findsOneWidget);
      expect(find.text('AUDIO & PLAYBACK'), findsOneWidget);
      expect(find.text('OFFLINE CACHE & STORAGE'), findsOneWidget);

      // Verify Key Controls
      expect(find.text('Autoplay on Launch'), findsOneWidget);
      expect(find.text('Cached Metadata Storage'), findsOneWidget);
      expect(find.text('Clear Non-Essential Cache'), findsOneWidget);
      expect(find.text('Reset All Preferences to Default'), findsOneWidget);
    });

    testWidgets('SettingsScreen Guest Listener renders on Samsung S24 dimensions without infinite-width crash', (tester) async {
      // Samsung S24 physical viewport dimensions: 412 x 915 with 1.25x text scaling
      tester.view.physicalSize = const Size(412 * 2.625, 915 * 2.625);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            stationsListProvider.overrideWith((ref) => Future.value([])),
            authNotifierProvider.overrideWith(
              () => FakeAuthNotifier(const AuthState.unauthenticated()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Guest Listener Account Card renders completely
      expect(find.text('ACCOUNT & PROFILE'), findsOneWidget);
      expect(find.text('Guest Listener'), findsOneWidget);
      expect(find.text('Sign in to sync favourites & preferences'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      // Verify no RenderFlex overflow or BoxConstraints errors occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('SettingsScreen Authenticated Listener renders account info and Sign Out tile', (tester) async {
      tester.view.physicalSize = const Size(412 * 2.625, 915 * 2.625);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final listenerUser = User(
        id: 10,
        name: 'Jordan Listener',
        email: 'jordan@pulsecast.fm',
        role: UserRole.listener,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            stationsListProvider.overrideWith((ref) => Future.value([])),
            authNotifierProvider.overrideWith(
              () => FakeAuthNotifier(AuthState.authenticated(listenerUser)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Listener Profile
      expect(find.text('Jordan Listener'), findsOneWidget);
      expect(find.text('jordan@pulsecast.fm'), findsOneWidget);
      expect(find.text('LISTENER'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Admin portal should NOT be visible to regular listener
      expect(find.text('Admin Management Portal'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('SettingsScreen Authenticated Admin renders Admin Portal shortcut', (tester) async {
      tester.view.physicalSize = const Size(412 * 2.625, 915 * 2.625);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adminUser = User(
        id: 1,
        name: 'Alex Admin',
        email: 'admin@pulsecast.fm',
        role: UserRole.admin,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            stationsListProvider.overrideWith((ref) => Future.value([])),
            authNotifierProvider.overrideWith(
              () => FakeAuthNotifier(AuthState.authenticated(adminUser)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Admin Profile & Admin Portal tile
      expect(find.text('Alex Admin'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('Admin Management Portal'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
