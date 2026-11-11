import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/cache/cache_providers.dart';
import '../../../../core/connectivity/connectivity_providers.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/sync/sync_queue.dart';
import '../../../../routing/route_names.dart';
import '../../../auth/domain/models/user.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/logout_confirmation_dialog.dart';
import '../../../stations/domain/models/station.dart';
import '../../../stations/presentation/providers/stations_provider.dart';
import '../../domain/models/user_settings.dart';
import '../providers/settings_providers.dart';

/// PulseCast Settings Screen aligned with Reference UI specification.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final isAuthenticated = authState.isAuthenticated && user != null;
    final isAdmin = isAuthenticated && user.role == UserRole.admin;
    final settings = ref.watch(userSettingsProvider);
    final connectivity = ref.watch(connectivityStatusProvider);
    final pendingSync = ref.watch(pendingSyncCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Account Card matching reference
              _buildProfileCard(
                context,
                isAuthenticated,
                user,
                isAdmin,
                connectivity,
                pendingSync,
              ),

              const SizedBox(height: 24),

              // 2. Settings Items List matching reference
              _buildSettingsItem(
                icon: Icons.volume_up_outlined,
                title: 'Audio Quality',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      settings.dataSaverMode ? 'Data Saver' : 'High',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                onTap: () => _showAudioQualityDialog(context, settings),
              ),

              _buildSettingsItem(
                icon: Icons.layers_outlined,
                title: 'Autoplay on Launch',
                trailing: Switch(
                  value: settings.autoplayOnLaunch,
                  activeColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  onChanged: (val) {
                    ref.read(userSettingsProvider.notifier).setAutoplay(val);
                  },
                ),
              ),

              _buildSettingsItem(
                icon: Icons.data_saver_on_outlined,
                title: 'Data Saver Mode',
                trailing: Switch(
                  value: settings.dataSaverMode,
                  activeColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  onChanged: (val) {
                    ref.read(userSettingsProvider.notifier).setDataSaver(val);
                  },
                ),
              ),

              _buildSettingsItem(
                icon: Icons.notifications_none_rounded,
                title: 'Playback & Controls',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onTap: () => _showPlaybackControlsSheet(context, settings),
              ),

              _buildSettingsItem(
                icon: Icons.wifi_off_rounded,
                title: 'Offline Mode & Cache',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onTap: () => _showOfflineCacheSheet(context, connectivity),
              ),

              _buildSettingsItem(
                icon: Icons.info_outline_rounded,
                title: 'About',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onTap: () => _showAboutDialog(context),
              ),

              // Admin Portal Link for authenticated admins
              if (isAdmin) ...[
                const SizedBox(height: 12),
                _buildSettingsItem(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin Dashboard',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  onTap: () => context.push(RouteNames.admin),
                ),
              ],

              const SizedBox(height: 36),

              // 3. Exact Reference Log Out / Sign In Button
              if (isAuthenticated)
                InkWell(
                  onTap: () async {
                    final shouldLogout =
                        await LogoutConfirmationDialog.show(context);
                    if (shouldLogout) {
                      await ref.read(authNotifierProvider.notifier).logout();
                      if (context.mounted) {
                        context.go(RouteNames.login);
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.logoutButtonBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Log Out',
                      style: TextStyle(
                        color: AppColors.logoutText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: () => context.push(RouteNames.login),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    bool isAuthenticated,
    User? user,
    bool isAdmin,
    ConnectivityStatus connectivity,
    int pendingSync,
  ) {
    final name =
        isAuthenticated ? (user?.name ?? 'Listener') : 'Guest Listener';
    final email = isAuthenticated
        ? (user?.email ?? 'signed-in user')
        : 'Sign in to sync favourites';

    return InkWell(
      onTap: () {
        if (!isAuthenticated) {
          context.push(RouteNames.login);
        } else {
          _showAccountInfoSheet(
            context,
            user!,
            isAdmin,
            connectivity,
            pendingSync,
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAccountInfoSheet(
    BuildContext context,
    User user,
    bool isAdmin,
    ConnectivityStatus connectivity,
    int pendingSync,
  ) {
    final roleLabel = isAdmin ? 'ADMIN' : 'LISTENER';
    final statusLabel = connectivity == ConnectivityStatus.online
        ? 'Connected & Synced'
        : connectivity == ConnectivityStatus.offline
            ? 'Offline'
            : 'Reconnecting';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _infoRow('Name', user.name),
              _infoRow('Email', user.email),
              _infoRow('Role', roleLabel),
              _infoRow('Cloud Sync', '$statusLabel ($pendingSync pending)'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAudioQualityDialog(BuildContext context, UserSettings settings) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Audio Quality',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'High (192-320 kbps MP3)',
                style: TextStyle(color: Colors.white),
              ),
              trailing: !settings.dataSaverMode
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                ref.read(userSettingsProvider.notifier).setDataSaver(false);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text(
                'Low / Data Saver (64 kbps)',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              trailing: settings.dataSaverMode
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                ref.read(userSettingsProvider.notifier).setDataSaver(true);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaybackControlsSheet(
    BuildContext context,
    UserSettings settings,
  ) {
    final stationsAsync = ref.read(stationsListProvider);
    final stations = stationsAsync.value ?? <Station>[];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Playback & Lock Screen',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Background audio playback and Android lock-screen media controls remain active while streaming.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text(
                'Default Startup Station',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (stations.isEmpty)
                const Text(
                  'Last played station will resume automatically.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        dense: true,
                        title: const Text(
                          'Last Selected Station',
                          style: TextStyle(color: Colors.white),
                        ),
                        trailing: settings.defaultStationId == null
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () {
                          ref
                              .read(userSettingsProvider.notifier)
                              .setDefaultStation(null);
                          Navigator.pop(ctx);
                        },
                      ),
                      ...stations.map(
                        (s) => ListTile(
                          dense: true,
                          title: Text(
                            s.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: settings.defaultStationId == s.id
                              ? const Icon(Icons.check,
                                  color: AppColors.primary)
                              : null,
                          onTap: () {
                            ref
                                .read(userSettingsProvider.notifier)
                                .setDefaultStation(s.id);
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOfflineCacheSheet(
    BuildContext context,
    ConnectivityStatus connectivity,
  ) {
    final cacheStats = ref.read(cacheStatsProvider);
    final syncStatus = ref.read(syncStatusProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Offline Mode & Cache',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              _infoRow('Network', connectivity.name.toUpperCase()),
              _infoRow('Sync State', syncStatus.name.toUpperCase()),
              _infoRow('Cached Data', '${cacheStats['kb']} KB'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(connectivityStatusProvider.notifier).checkNow();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Check Server'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final cleared = await ref
                            .read(userSettingsProvider.notifier)
                            .clearNonEssentialCache();
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Cleared $cleared cached entries.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Clear Cache'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'About PulseCast',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'PulseCast Internet Radio Streaming v1.0.0\nHigh-fidelity 24/7 automated music broadcasting.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
