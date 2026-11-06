import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_typography.dart';
import '../../routing/route_names.dart';
import '../auth/presentation/providers/auth_providers.dart';
import 'presentation/providers/admin_providers.dart';
import 'presentation/widgets/admin_stat_card.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.adminDashboard),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.settings);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.accentAmber),
            tooltip: 'Settings & Preferences',
            onPressed: () => context.push(RouteNames.settings),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Dashboard',
            onPressed: () => ref.invalidate(adminDashboardStatsProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(adminDashboardStatsProvider);
            await ref.read(adminDashboardStatsProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Admin Status Banner
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentAmber.withValues(alpha: 0.15),
                        AppColors.cardSurface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusLarge,
                    ),
                    border: Border.all(
                      color: AppColors.accentAmber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: AppColors.accentAmber,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Administrator Portal',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Signed in as ${user?.name ?? "Administrator"} (${user?.email ?? ""})',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingLarge),

                // Live Analytics & Infrastructure Stats
                Text(
                  'System Overview',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingMedium),

                statsAsync.when(
                  data: (stats) {
                    final songStats = stats.songStats;
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AdminStatCard(
                                title: 'Total Songs',
                                value: '${songStats?.totalSongs ?? 0}',
                                icon: Icons.library_music_rounded,
                                color: AppColors.accentViolet,
                                subtitle: '${songStats?.activeSongs ?? 0} active',
                              ),
                            ),
                            const SizedBox(width: AppDimensions.paddingMedium),
                            Expanded(
                              child: AdminStatCard(
                                title: 'Storage Used',
                                value: songStats?.formattedTotalStorage ?? '0 MB',
                                icon: Icons.cloud_done_rounded,
                                color: AppColors.accentCyan,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.paddingMedium),
                        Row(
                          children: [
                            Expanded(
                              child: AdminStatCard(
                                title: 'Broadcast Stations',
                                value: '${stats.totalStations}',
                                icon: Icons.cell_tower_rounded,
                                color: AppColors.accentEmerald,
                                subtitle: '${stats.activeStations} online',
                              ),
                            ),
                            const SizedBox(width: AppDimensions.paddingMedium),
                            Expanded(
                              child: AdminStatCard(
                                title: 'Program Schedules',
                                value: '${stats.totalSchedules}',
                                icon: Icons.calendar_month_rounded,
                                color: AppColors.accentAmber,
                                subtitle: '${stats.publishedSchedules} published',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.paddingMedium),

                        // System Health Row
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.paddingMedium,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurface,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMedium),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: stats.isServerHealthy
                                      ? AppColors.connected
                                      : AppColors.buffering,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Backend API Gateway: ${stats.serverStatus.toUpperCase()}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Synced ${stats.lastChecked.hour.toString().padLeft(2, '0')}:${stats.lastChecked.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  error: (e, _) => Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(
                        color: AppColors.accentCoral.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Failed to load analytics: $e',
                      style: const TextStyle(color: AppColors.accentCoral),
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.paddingLarge),

                Text(
                  'Management Modules',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingMedium),

                _buildModuleCard(
                  icon: Icons.cell_tower_rounded,
                  title: 'Station Management',
                  description:
                      'Manage broadcast stations, stream URLs, and metadata',
                  color: AppColors.accentCyan,
                  onTap: () => context.push(RouteNames.adminStations),
                ),
                const SizedBox(height: AppDimensions.paddingMedium),

                _buildModuleCard(
                  icon: Icons.library_music_rounded,
                  title: 'Music Library (Supabase)',
                  description:
                      'Private bucket tracks, metadata editing, audio upload & preview',
                  color: AppColors.accentViolet,
                  onTap: () => context.push(RouteNames.adminSongs),
                ),
                const SizedBox(height: AppDimensions.paddingMedium),

                _buildModuleCard(
                  icon: Icons.calendar_month_rounded,
                  title: 'Broadcast Schedules',
                  description:
                      'Program grid, playlist sequencing, and conflict detection',
                  color: AppColors.accentAmber,
                  onTap: () => context.push(RouteNames.adminSchedules),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
