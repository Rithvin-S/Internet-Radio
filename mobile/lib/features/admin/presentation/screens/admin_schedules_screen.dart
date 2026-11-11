import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import 'package:pulsecast/features/admin/domain/models/admin_schedule.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_schedule_form_dialog.dart';
import '../widgets/confirm_dialog.dart';
import 'admin_schedule_playlist_screen.dart';

/// Admin Broadcast Schedules Screen aligned with the Reference UI design language.
class AdminSchedulesScreen extends ConsumerWidget {
  final bool embedded;

  const AdminSchedulesScreen({
    super.key,
    this.embedded = false,
  });

  static Future<void> openCreateDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
  }

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
          const SnackBar(
            content: Text('Schedule publication status updated.'),
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

  Future<void> _handleEdit(
    BuildContext context,
    WidgetRef ref,
    AdminSchedule schedule,
  ) async {
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

  void _openPlaylist(BuildContext context, AdminSchedule schedule) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdminSchedulePlaylistScreen(
          scheduleId: schedule.id,
          schedule: schedule,
        ),
      ),
    );
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
              backgroundColor: AppColors.background,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: context.canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      color: Colors.white,
                      onPressed: () => context.pop(),
                    )
                  : null,
              title: const Text(
                'Schedule',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 22),
                  tooltip: 'Refresh Schedules',
                  onPressed: () => ref.invalidate(adminSchedulesListProvider),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16, left: 4),
                  child: GestureDetector(
                    onTap: () => openCreateDialog(context, ref),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.black, size: 22),
                    ),
                  ),
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar (Station + Status)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  _buildFilterPill(
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
                        child: _buildFilterPill(
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
                    color: AppColors.border,
                    indent: 6,
                    endIndent: 6,
                    width: 16,
                  ),
                  _buildFilterPill(
                    label: 'All Statuses',
                    isSelected: selectedStatus == null,
                    onTap: () => ref
                        .read(adminScheduleStatusFilterProvider.notifier)
                        .setStatus(null),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    label: 'Published',
                    isSelected: selectedStatus == 'published',
                    onTap: () => ref
                        .read(adminScheduleStatusFilterProvider.notifier)
                        .setStatus(selectedStatus == 'published' ? null : 'published'),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    label: 'Draft',
                    isSelected: selectedStatus == 'draft',
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
                            padding: EdgeInsets.symmetric(vertical: 72),
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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: schedules.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildScheduleCard(context, ref, schedules[index]);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
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
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.accentCoral),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(adminSchedulesListProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
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

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(
    BuildContext context,
    WidgetRef ref,
    AdminSchedule schedule,
  ) {
    final isPublished = schedule.isPublished;

    return InkWell(
      onTap: () => _openPlaylist(context, schedule),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPublished
                    ? AppColors.brandGreenDark
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPublished
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.border,
                ),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: isPublished ? AppColors.primary : AppColors.accentAmber,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          schedule.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPublished
                              ? AppColors.primary.withValues(alpha: 0.16)
                              : AppColors.accentAmber.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPublished ? 'LIVE' : 'DRAFT',
                          style: TextStyle(
                            color: isPublished ? AppColors.primary : AppColors.accentAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    schedule.stationName != null
                        ? '${schedule.stationName} • ${schedule.category ?? "Music"}'
                        : (schedule.category ?? 'Music'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${schedule.scheduleDate} • ${schedule.timeRange} • ${schedule.songCount} tracks',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              color: AppColors.surfaceElevated,
              onSelected: (value) {
                switch (value) {
                  case 'playlist':
                    _openPlaylist(context, schedule);
                    break;
                  case 'publish':
                    _handleTogglePublish(context, ref, schedule);
                    break;
                  case 'duplicate':
                    _handleDuplicate(context, ref, schedule);
                    break;
                  case 'edit':
                    _handleEdit(context, ref, schedule);
                    break;
                  case 'delete':
                    _handleDelete(context, ref, schedule);
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'playlist',
                  child: Row(
                    children: [
                      Icon(Icons.queue_music_rounded, color: AppColors.primary, size: 18),
                      SizedBox(width: 10),
                      Text('Manage Playlist'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'publish',
                  child: Row(
                    children: [
                      Icon(
                        isPublished ? Icons.unpublished_outlined : Icons.publish_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(isPublished ? 'Unpublish to Draft' : 'Publish Programme'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.content_copy_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text('Duplicate'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text('Edit Schedule'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: AppColors.accentCoral, size: 18),
                      SizedBox(width: 10),
                      Text('Delete', style: TextStyle(color: AppColors.accentCoral)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
