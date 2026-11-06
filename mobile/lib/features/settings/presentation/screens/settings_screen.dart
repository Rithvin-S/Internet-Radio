import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulsecast/core/constants/app_colors.dart';
import 'package:pulsecast/core/constants/app_dimensions.dart';
import 'package:pulsecast/core/theme/app_typography.dart';
import 'package:pulsecast/core/cache/cache_providers.dart';
import 'package:pulsecast/core/connectivity/connectivity_providers.dart';
import 'package:pulsecast/core/connectivity/connectivity_service.dart';
import 'package:pulsecast/core/sync/sync_providers.dart';
import 'package:pulsecast/core/sync/sync_queue.dart';
import 'package:pulsecast/features/auth/domain/models/user.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_providers.dart';
import 'package:pulsecast/features/auth/presentation/widgets/logout_confirmation_dialog.dart';
import 'package:pulsecast/features/settings/domain/models/user_settings.dart';
import 'package:pulsecast/features/settings/presentation/providers/settings_providers.dart';
import 'package:pulsecast/features/stations/presentation/providers/stations_provider.dart';
import 'package:pulsecast/routing/route_names.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final connStatus = ref.watch(connectivityStatusProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);
    final cacheStats = ref.watch(cacheStatsProvider);
    final stationsAsync = ref.watch(stationsListProvider);

    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final isAuthenticated = authState.isAuthenticated;
    final isAdmin = authState.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Preferences'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        children: [
          // Section 0: Account & Authentication
          _buildSectionHeader('Account & Profile'),
          _buildAccountCard(context, ref, user, isAuthenticated, isAdmin),
          const SizedBox(height: 24),

          // Section 1: Network & Synchronization
          _buildSectionHeader('Network & Synchronization'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: connStatus == ConnectivityStatus.online
                        ? AppColors.accentEmerald
                        : (connStatus == ConnectivityStatus.serverUnavailable
                            ? AppColors.accentAmber
                            : AppColors.accentCoral),
                  ),
                  title: const Text('Connectivity Status'),
                  subtitle: Text(
                    connStatus == ConnectivityStatus.online
                        ? 'Connected to PulseCast Gateway'
                        : (connStatus == ConnectivityStatus.serverUnavailable
                            ? 'Internet Active — Server Reconnecting'
                            : 'Offline — Using local cached information'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final status = await ref
                          .read(connectivityStatusProvider.notifier)
                          .checkNow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(status == ConnectivityStatus.online
                                ? 'Gateway is reachable'
                                : (status == ConnectivityStatus.serverUnavailable
                                    ? 'Internet is active, server is waking up'
                                    : 'Gateway is currently unreachable')),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: const Text('Check'),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: Icon(
                    syncStatus == SyncStatus.syncing
                        ? Icons.sync_rounded
                        : syncStatus == SyncStatus.error
                            ? Icons.sync_problem_rounded
                            : Icons.cloud_done_rounded,
                    color: syncStatus == SyncStatus.error
                        ? AppColors.accentCoral
                        : AppColors.accentCyan,
                  ),
                  title: const Text('Cloud Synchronization'),
                  subtitle: Text(
                    pendingCount > 0
                        ? '$pendingCount pending mutation(s) queued for sync'
                        : 'Favorites and preferences are up to date',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: pendingCount > 0
                      ? IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: AppColors.accentCyan),
                          onPressed: () {
                            ref.read(syncServiceProvider).processQueue(
                              onExecute: (_) async => true,
                            );
                          },
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Audio & Playback Preferences
          _buildSectionHeader('Audio & Playback'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Default Station Selector
                stationsAsync.when(
                  data: (stations) {
                    final currentDefault = stations.where((s) => s.id == settings.defaultStationId);
                    final defaultStationName = currentDefault.isNotEmpty
                        ? currentDefault.first.name
                        : (settings.defaultStationId == 6
                            ? 'Channel 6 — PulseCast Radio'
                            : (settings.defaultStationId == null
                                ? 'None (Restore Last Stream)'
                                : 'Station #${settings.defaultStationId}'));

                    return ListTile(
                      leading: const Icon(Icons.radio_rounded, color: AppColors.accentCyan),
                      title: const Text('Default Station on Launch'),
                      subtitle: Text(
                        defaultStationName,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      onTap: () => _showDefaultStationDialog(context, ref, stations, settings.defaultStationId),
                    );
                  },
                  loading: () => const ListTile(
                    leading: Icon(Icons.radio_rounded, color: AppColors.textSecondary),
                    title: Text('Default Station'),
                    subtitle: Text('Loading stations...'),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const Divider(height: 1, color: AppColors.border),

                // Autoplay Switch
                SwitchListTile(
                  secondary: const Icon(Icons.play_circle_outline_rounded, color: AppColors.accentCyan),
                  title: const Text('Autoplay on Launch'),
                  subtitle: const Text(
                    'Automatically stream the default station when the app starts (requires network).',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.autoplayOnLaunch,
                  activeColor: AppColors.accentCyan,
                  onChanged: (val) {
                    ref.read(userSettingsProvider.notifier).setAutoplay(val);
                  },
                ),
                const Divider(height: 1, color: AppColors.border),

                // Data Saver Mode
                SwitchListTile(
                  secondary: const Icon(Icons.data_saver_on_rounded, color: AppColors.accentCyan),
                  title: const Text('Data Saver Mode'),
                  subtitle: const Text(
                    'Prefers lightweight metadata polling and lower image resolutions.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.dataSaverMode,
                  activeColor: AppColors.accentCyan,
                  onChanged: (val) {
                    ref.read(userSettingsProvider.notifier).setDataSaver(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: Library & Catalog Display
          _buildSectionHeader('Catalog & Sorting'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sort_rounded, color: AppColors.accentCyan),
                  title: const Text('Station Sort Order'),
                  subtitle: Text(
                    _getStationSortLabel(settings.stationSort),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  onTap: () => _showSortOrderDialog(context, ref, settings.stationSort),
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.filter_list_rounded, color: AppColors.accentCyan),
                  title: const Text('Default Library Filter'),
                  subtitle: Text(
                    settings.preferredLibraryFilter == 'live'
                        ? 'Live Broadcasts'
                        : settings.preferredLibraryFilter == 'queue'
                            ? 'In Queue'
                            : 'All Tracks',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  onTap: () => _showFilterDialog(context, ref, settings.preferredLibraryFilter),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 4: Offline Cache & Storage Management
          _buildSectionHeader('Offline Cache & Storage'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage_rounded, color: AppColors.accentAmber),
                  title: const Text('Cached Metadata Storage'),
                  subtitle: Text(
                    '${cacheStats['kb']} KB (${cacheStats['bytes']} bytes) used for offline station and track catalogs',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_rounded, color: AppColors.accentCoral),
                  title: const Text(
                    'Clear Non-Essential Cache',
                    style: TextStyle(color: AppColors.accentCoral),
                  ),
                  subtitle: const Text(
                    'Removes cached station catalogs. Favorites, settings, and auth sessions are preserved.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () => _showClearCacheDialog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 5: Reset All
          Center(
            child: TextButton.icon(
              onPressed: () => _showResetDefaultsDialog(context, ref),
              icon: const Icon(Icons.restore_rounded, size: 18, color: AppColors.textSecondary),
              label: const Text(
                'Reset All Preferences to Default',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 1.1,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    WidgetRef ref,
    User? user,
    bool isAuthenticated,
    bool isAdmin,
  ) {
    if (isAuthenticated && user != null) {
      final name = user.name.trim();
      final initials = name.isNotEmpty
          ? name.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase()
          : 'U';
      final displayInitials = initials.isNotEmpty ? initials : 'U';
      final displayName = name.isNotEmpty ? name : 'PulseCast User';
      final displayEmail = user.email.trim().isNotEmpty ? user.email.trim() : 'No email provided';

      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMedium),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: isAdmin ? AppColors.accentAmber : AppColors.accentCyan,
                    child: Text(
                      displayInitials,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.background,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isAdmin ? AppColors.accentAmber : AppColors.accentCyan)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                user.role.toRoleString().toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: isAdmin ? AppColors.accentAmber : AppColors.accentCyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          displayEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin) ...[
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.accentAmber),
                title: const Text('Admin Management Portal'),
                subtitle: const Text(
                  'Manage stations, song library & schedules',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentAmber,
                      foregroundColor: AppColors.background,
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                    ),
                    onPressed: () => context.push(RouteNames.admin),
                    child: const Text('Open', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
            const Divider(height: 1, color: AppColors.border),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.accentCoral),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.accentCoral, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'End active session on this device',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              onTap: () async {
                final shouldLogout = await LogoutConfirmationDialog.show(context);
                if (shouldLogout) {
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (context.mounted) {
                    context.go(RouteNames.login);
                  }
                }
              },
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surface,
            child: const Icon(Icons.person_outline_rounded, color: AppColors.textSecondary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest Listener',
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sign in to sync favourites & preferences',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: AppColors.background,
                minimumSize: const Size(0, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
              ),
              onPressed: () => context.push(RouteNames.login),
              child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  String _getStationSortLabel(StationSort sort) {
    switch (sort) {
      case StationSort.defaultSort:
        return 'Default Catalog Order';
      case StationSort.nameAsc:
        return 'Station Name (A to Z)';
      case StationSort.nameDesc:
        return 'Station Name (Z to A)';
      case StationSort.genre:
        return 'Grouped by Genre';
    }
  }

  void _showDefaultStationDialog(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> stations,
    int? currentId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Select Default Station'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              RadioListTile<int?>(
                title: const Text('Channel 6 — PulseCast Radio (Default)'),
                subtitle: const Text('24/7 automated music shuffle'),
                value: 6,
                groupValue: currentId ?? 6,
                activeColor: AppColors.accentCyan,
                onChanged: (val) {
                  ref.read(userSettingsProvider.notifier).setDefaultStation(val);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<int?>(
                title: const Text('None (Restore Last Stream)'),
                value: null,
                groupValue: currentId,
                activeColor: AppColors.accentCyan,
                onChanged: (val) {
                  ref.read(userSettingsProvider.notifier).setDefaultStation(val);
                  Navigator.pop(ctx);
                },
              ),
              ...stations.where((s) => s.id != 6).map((s) => RadioListTile<int?>(
                    title: Text(s.name),
                    subtitle: Text(s.genre ?? 'Radio'),
                    value: s.id,
                    groupValue: currentId,
                    activeColor: AppColors.accentCyan,
                    onChanged: (val) {
                      ref.read(userSettingsProvider.notifier).setDefaultStation(val);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortOrderDialog(BuildContext context, WidgetRef ref, StationSort current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Station Sort Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: StationSort.values
              .map((s) => RadioListTile<StationSort>(
                    title: Text(_getStationSortLabel(s)),
                    value: s,
                    groupValue: current,
                    activeColor: AppColors.accentCyan,
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(userSettingsProvider.notifier).setStationSort(val);
                      }
                      Navigator.pop(ctx);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref, String current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Default Library Filter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('All Tracks'),
              value: 'all',
              groupValue: current,
              activeColor: AppColors.accentCyan,
              onChanged: (val) {
                if (val != null) {
                  ref.read(userSettingsProvider.notifier).setPreferredLibraryFilter(val);
                }
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text('Live Broadcasts Only'),
              value: 'live',
              groupValue: current,
              activeColor: AppColors.accentCyan,
              onChanged: (val) {
                if (val != null) {
                  ref.read(userSettingsProvider.notifier).setPreferredLibraryFilter(val);
                }
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text('In Queue Tracks'),
              value: 'queue',
              groupValue: current,
              activeColor: AppColors.accentCyan,
              onChanged: (val) {
                if (val != null) {
                  ref.read(userSettingsProvider.notifier).setPreferredLibraryFilter(val);
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Clear Non-Essential Cache?'),
        content: const Text(
          'This will purge cached station metadata and catalog tracks. Your favorites, preferences, and login state will remain untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCoral,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final cleared = await ref
                  .read(userSettingsProvider.notifier)
                  .clearNonEssentialCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cleared $cleared non-essential cache items.'),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                );
              }
            },
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  void _showResetDefaultsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Reset All Settings?'),
        content: const Text(
          'Are you sure you want to reset all playback, catalog, and synchronization settings to their original defaults?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentAmber,
              foregroundColor: AppColors.background,
              minimumSize: const Size(0, 36),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(userSettingsProvider.notifier).resetToDefaults();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All settings reset to default.'),
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
