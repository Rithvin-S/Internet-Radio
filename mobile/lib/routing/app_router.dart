import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import 'app_shell.dart';
import '../features/radio/presentation/screens/radio_screen.dart';
import '../features/stations/presentation/screens/stations_screen.dart';
import '../features/library/library_screen.dart';
import '../features/favourites/favourites_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/presentation/screens/admin_songs_screen.dart';
import '../features/admin/presentation/screens/admin_song_upload_screen.dart';
import '../features/admin/presentation/screens/admin_schedules_screen.dart';
import '../features/admin/presentation/screens/admin_stations_portal_screen.dart';

/// Navigation states based on backend RBAC role
enum NavRoleState {
  loggedOut,
  listener,
  admin,
}

/// Computes the active navigation role state based on authentication status and backend role
final navRoleStateProvider = Provider<NavRoleState>((ref) {
  final authState = ref.watch(authNotifierProvider);
  if (!authState.isAuthenticated) {
    return NavRoleState.loggedOut;
  }
  return authState.isAdmin ? NavRoleState.admin : NavRoleState.listener;
});

/// ChangeNotifier bridging Riverpod auth state changes to GoRouter refresh
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (previous, next) {
      if (previous?.status != next.status ||
          previous?.user != next.user ||
          previous?.sessionExpired != next.sessionExpired) {
        notifyListeners();
      }
    });
  }
}

/// Provider exposing role-specific GoRouter instance
final appRouterProvider = Provider<GoRouter>((ref) {
  final navRole = ref.watch(navRoleStateProvider);
  final refreshNotifier = RouterRefreshNotifier(ref);
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  String? redirectGuard(BuildContext context, GoRouterState state) {
    final authState = ref.read(authNotifierProvider);
    final isAuth = authState.isAuthenticated;
    final isAdmin = authState.isAdmin;
    final path = state.matchedLocation;

    final isLoggingIn = path == RouteNames.login;
    final isRegistering = path == RouteNames.register;
    final isAdminRoute = path.startsWith(RouteNames.admin);

    // 1. If authenticated, prevent navigating to register (or login when already authenticated)
    if (isAuth && (isLoggingIn || isRegistering)) {
      return RouteNames.home;
    }

    // 2. Role-Based Access Guard for Admin routes
    if (isAdminRoute) {
      if (!isAuth) {
        // Unauthenticated guest: redirect to login with return path
        return '${RouteNames.login}?redirect=${Uri.encodeComponent(path)}';
      }
      if (!isAdmin) {
        // Authenticated as Listener: forbid access to Admin Portal, redirect to Settings
        return RouteNames.settings;
      }
    }

    return null;
  }

  final List<StatefulShellBranch> branches;
  final List<RouteBase> topLevelRoutes;

  switch (navRole) {
    case NavRoleState.loggedOut:
      // Exactly 2 tabs: 0: Radio, 1: Sign In
      branches = [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.home, // '/'
              builder: (context, state) => const RadioScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.login,
              builder: (context, state) {
                final redirect = state.uri.queryParameters['redirect'];
                return LoginScreen(redirect: redirect);
              },
            ),
          ],
        ),
      ];

      topLevelRoutes = [
        GoRoute(
          path: RouteNames.register,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: RouteNames.settings,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: RouteNames.stations,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const StationsScreen(),
        ),
        GoRoute(
          path: RouteNames.library,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const LibraryScreen(),
        ),
        GoRoute(
          path: RouteNames.favourites,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const FavouritesScreen(),
        ),
        // Guarded admin routes
        GoRoute(
          path: RouteNames.admin,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: RouteNames.adminSongs,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminSongsScreen(),
        ),
        GoRoute(
          path: RouteNames.adminSongUpload,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminSongUploadScreen(),
        ),
        GoRoute(
          path: RouteNames.adminStations,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminStationsPortalScreen(),
        ),
        GoRoute(
          path: RouteNames.adminSchedules,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminSchedulesScreen(),
        ),
      ];
      break;

    case NavRoleState.listener:
      // Exactly 3 tabs: 0: Radio, 1: Favourites, 2: Settings
      branches = [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.home, // '/'
              builder: (context, state) => const RadioScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.favourites,
              builder: (context, state) => const FavouritesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ];

      topLevelRoutes = [
        GoRoute(
          path: RouteNames.login,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: RouteNames.register,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: RouteNames.stations,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const StationsScreen(),
        ),
        GoRoute(
          path: RouteNames.library,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const LibraryScreen(),
        ),
        // Guarded admin routes
        GoRoute(
          path: RouteNames.admin,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: RouteNames.adminSongs,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminSongsScreen(),
        ),
        GoRoute(
          path: RouteNames.adminSongUpload,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminSongUploadScreen(),
        ),
        GoRoute(
          path: RouteNames.adminStations,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminStationsPortalScreen(),
        ),
        GoRoute(
          path: RouteNames.adminSchedules,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminSchedulesScreen(),
        ),
      ];
      break;

    case NavRoleState.admin:
      // Exactly 4 tabs: 0: Radio, 1: Library, 2: Stations, 3: Settings
      branches = [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.home, // '/'
              builder: (context, state) => const RadioScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.adminSongs,
              builder: (context, state) => const AdminSongsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.adminStations,
              builder: (context, state) => const AdminStationsPortalScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ];

      topLevelRoutes = [
        GoRoute(
          path: RouteNames.login,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: RouteNames.register,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: RouteNames.favourites,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const FavouritesScreen(),
        ),
        // Aliases for admin
        GoRoute(
          path: RouteNames.library,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const LibraryScreen(),
        ),
        GoRoute(
          path: RouteNames.stations,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const StationsScreen(),
        ),
        GoRoute(
          path: RouteNames.admin,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: RouteNames.adminSongUpload,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminSongUploadScreen(),
        ),
        GoRoute(
          path: RouteNames.adminSchedules,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AdminSchedulesScreen(),
        ),
      ];
      break;
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.home,
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: redirectGuard,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: branches,
      ),
      ...topLevelRoutes,
    ],
  );
});
