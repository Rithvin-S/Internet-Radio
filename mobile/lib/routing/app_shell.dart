import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/widgets/offline_banner.dart';
import '../features/player/presentation/widgets/mini_player.dart';
import 'app_router.dart';

/// AppShell provides dynamic role-based BottomNavigationBar, layout wrapper,
/// persistent mini-player anchor, and global offline indicator banner
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    debugPrint('*** APP_SHELL _onTap: $index, current: ${navigationShell.currentIndex} ***');
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navRole = ref.watch(navRoleStateProvider);

    final List<BottomNavigationBarItem> items;
    switch (navRole) {
      case NavRoleState.loggedOut:
        // Exactly two tabs for unauthenticated guest
        items = const [
          BottomNavigationBarItem(
            icon: Icon(Icons.radio_rounded),
            label: 'Radio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.login_rounded),
            label: 'Sign In',
          ),
        ];
        break;
      case NavRoleState.listener:
        // Exactly three tabs for signed-in normal listener
        items = const [
          BottomNavigationBarItem(
            icon: Icon(Icons.radio_rounded),
            label: 'Radio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_rounded),
            label: AppStrings.navFavourites,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ];
        break;
      case NavRoleState.admin:
        // Exactly four tabs for authenticated admin
        items = const [
          BottomNavigationBarItem(
            icon: Icon(Icons.radio_rounded),
            label: 'Radio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music_rounded),
            label: AppStrings.navLibrary,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cell_tower_rounded),
            label: AppStrings.navStations,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ];
        break;
    }

    final safeIndex = navigationShell.currentIndex.clamp(0, items.length - 1);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Only show mini-player on non-Radio tabs to avoid duplicate controls on the main player screen
          if (navigationShell.currentIndex != 0) const MiniPlayerWidget(),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: safeIndex,
              onTap: _onTap,
              items: items,
            ),
          ),
        ],
      ),
    );
  }
}
