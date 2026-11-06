import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:pulsecast/features/admin/domain/models/admin_schedule.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_schedule_form_dialog.dart';
import '../widgets/confirm_dialog.dart';
import 'admin_schedule_playlist_screen.dart';

class AdminSchedulesScreen extends ConsumerWidget {
  final bool embedded;

  const AdminSchedulesScreen({
    super.key,
    this.embedded = false,
  });

  Future<void> _handleTogglePublish(
    BuildContext context,
    WidgetRef ref,
    AdminSchedule schedule,
  ) async {
    try {
      final repo = ref.read(adminScheduleRepositoryProvider);
      await repo.togglePublishSchedule(schedule.id);
      ref.invalidate(adminSchedulesListProvider);
      ref.invalidate(adminDashboardStatsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Schedule publication status updated.',
            ),
            backgroundColor: AppColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot publish: ${e.message}'),
            backgroundColor: AppColors.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDuplicate(
    BuildContext context,
    WidgetRef ref,
    AdminSchedule schedule,
  ) async {
    try {
      final repo = ref.read(adminScheduleRepositoryProvider);
      final duplicated = await repo.duplicateSchedule(schedule.id);
      ref.invalidate(adminSchedulesListProvider);
      ref.invalidate(adminDashboardStatsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Duplicated as draft: "${duplicated.title}"'),
            backgroundColor: AppColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate: $e'),
            backgroundColor: AppColors.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    AdminSchedule schedule,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Program Schedule',
      message:
          'Are you sure you want to delete "${schedule.title}"? Associated playlist assignments will be removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );

    if (!confirmed || !context.mounted) return;

    try {
      final repo = ref.read(adminScheduleRepositoryProvider);
      await repo.deleteSchedule(schedule.id);
      ref.invalidate(adminSchedulesListProvider);
      ref.invalidate(adminDashboardStatsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Schedule "${schedule.title}" deleted.'),
            backgroundColor: AppColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppColors.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(adminSchedulesListProvider);
    final stationsAsync = ref.watch(adminStationsListProvider);
    final selectedStationId = ref.watch(adminScheduleStationFilterProvider);
    final selectedStatus = ref.watch(adminScheduleStatusFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: embedded
          ? null
          : AppBar(
              title: const Text('Broadcast Schedules'),
              backgroundColor: AppColors.background,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh Schedules',
                  onPressed: () => ref.invalidate(adminSchedulesListProvider),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await AdminScheduleFormDialog.show(
            context,
            onSave: (schedule) async {
              final repo = ref.read(adminScheduleRepositoryProvider);
              await repo.createSchedule(schedule);
            },
          );
          if (created) {
            ref.invalidate(adminSchedulesListProvider);
            ref.invalidate(adminDashboardStatsProvider);
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Schedule',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar (Station + Status)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingLarge,
                ),
                children: [
                  // Station filter
                  _buildChip(
                    label: 'All Stations',
                    isSelected: selectedStationId == null,
                    onTap: () => ref
                        .read(adminScheduleStationFilterProvider.notifier)
                        .selectStation(null),
                  ),
                  const SizedBox(width: 8),

                  ...stationsAsync.when(
                    data: (stations) => stations.map((s) {
                      final isSelected = selectedStationId == s.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildChip(
                          label: s.name,
                          isSelected: isSelected,
                          onTap: () => ref
                              .read(adminScheduleStationFilterProvider.notifier)
                              .selectStation(isSelected ? null : s.id),
                        ),
                      );
                    }).toList(),
                    loading: () => [],
                    error: (_, __) => [],
                  ),

                  const VerticalDivider(
                    color: AppColors.borderSubtle,
                    indent: 8,
                    endIndent: 8,
                    width: 16,
                  ),

                  // Status filter
                  _buildChip(
                    label: 'All Statuses',
                    isSelected: selectedStatus == null,
                    onTap: () => ref
                        .read(adminScheduleStatusFilterProvider.notifier)
                        .setStatus(null),
                  ),
                  const SizedBox(width: 8),
                  _buildChip(
                    label: 'Published',
                    isSelected: selectedStatus == 'published',
                    color: AppColors.accentEmerald,
                    onTap: () => ref
                        .read(adminScheduleStatusFilterProvider.notifier)
                        .setStatus(selectedStatus == 'published' ? null : 'published'),
                  ),
                  const SizedBox(width: 8),
                  _buildChip(
                    label: 'Draft',
                    isSelected: selectedStatus == 'draft',
                    color: AppColors.accentAmber,
                    onTap: () => ref
                        .read(adminScheduleStatusFilterProvider.notifier)
                        .setStatus(selectedStatus == 'draft' ? null : 'draft'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Schedule List
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () async {
                  ref.invalidate(adminSchedulesListProvider);
                  await ref.read(adminSchedulesListProvider.future);
                },
                child: schedulesAsync.when(
                  data: (schedules) {
                    if (schedules.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: Text(
                                'No program schedules found.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.paddingLarge,
                        AppDimensions.paddingSmall,
                        AppDimensions.paddingLarge,
                        80,
                      ),
                      itemCount: schedules.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppDimensions.paddingMedium),
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];
                        return _buildScheduleCard(context, ref, schedule);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.accentCoral,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load schedules: $e',
                          style: const TextStyle(color: AppColors.accentCoral),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(adminSchedulesListProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? AppColors.primary;
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: isSelected
          ? effectiveColor.withValues(alpha: 0.2)
          : AppColors.cardSurface,
      labelStyle: TextStyle(
        color: isSelected ? effectiveColor : AppColors.textSecondary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? effectiveColor : AppColors.borderSubtle,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildScheduleCard(
    BuildContext context,
    WidgetRef ref,
    AdminSchedule schedule,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.accentAmber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      schedule.stationName != null
                          ? '${schedule.stationName} • ${schedule.category ?? "Music"}'
                          : (schedule.category ?? 'Music'),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: schedule.isPublished
                      ? AppColors.accentEmerald.withValues(alpha: 0.2)
                      : AppColors.accentAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  schedule.isPublished ? 'PUBLISHED' : 'DRAFT',
                  style: TextStyle(
                    color: schedule.isPublished
                        ? AppColors.accentEmerald
                        : AppColors.accentAmber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Date, Time range, and assigned songs badge
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '${schedule.scheduleDate}  ${schedule.timeRange}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  '${schedule.songCount} tracks',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 4),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Toggle publish
              IconButton(
                icon: Icon(
                  schedule.isPublished
                      ? Icons.check_circle_rounded
                      : Icons.publish_rounded,
                  color: schedule.isPublished
                      ? AppColors.accentEmerald
                      : AppColors.accentAmber,
                  size: 20,
                ),
                tooltip:
                    schedule.isPublished ? 'Unpublish to Draft' : 'Publish Programme',
                onPressed: () =>
                    _handleTogglePublish(context, ref, schedule),
              ),
              // Open Playlist
              IconButton(
                icon: const Icon(
                  Icons.queue_music_rounded,
                  color: AppColors.accentCyan,
                  size: 20,
                ),
                tooltip: 'Manage Playlist Tracks',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AdminSchedulePlaylistScreen(
                        scheduleId: schedule.id,
                        schedule: schedule,
                      ),
                    ),
                  );
                },
              ),
              // Duplicate
              IconButton(
                icon: const Icon(
                  Icons.content_copy_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'Duplicate Schedule',
                onPressed: () => _handleDuplicate(context, ref, schedule),
              ),
              // Edit
              IconButton(
                icon: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'Edit Schedule',
                onPressed: () async {
                  final saved = await AdminScheduleFormDialog.show(
                    context,
                    schedule: schedule,
                    onSave: (updated) async {
                      final repo = ref.read(adminScheduleRepositoryProvider);
                      await repo.updateSchedule(schedule.id, updated);
                    },
                  );
                  if (saved) {
                    ref.invalidate(adminSchedulesListProvider);
                  }
                },
              ),
              // Delete
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.accentCoral,
                  size: 20,
                ),
                tooltip: 'Delete Schedule',
                onPressed: () => _handleDelete(context, ref, schedule),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
