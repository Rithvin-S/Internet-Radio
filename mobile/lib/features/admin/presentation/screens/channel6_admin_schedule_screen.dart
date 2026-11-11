import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../routing/route_names.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/channel6_schedule_state.dart';
import '../providers/channel6_schedule_provider.dart';
import '../widgets/confirm_dialog.dart';

/// Dedicated Admin-Only Channel 6 Up Next Queue Screen.
/// Replaces traditional calendar scheduling for Channel 6 with a real-time
/// Up Next play queue backed by the local Node.js music folder and shuffle fallback.
class Channel6AdminScheduleScreen extends ConsumerStatefulWidget {
  const Channel6AdminScheduleScreen({super.key});

  @override
  ConsumerState<Channel6AdminScheduleScreen> createState() =>
      _Channel6AdminScheduleScreenState();
}

class _Channel6AdminScheduleScreenState
    extends ConsumerState<Channel6AdminScheduleScreen> {
  bool _isBusyAction = false;

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.accentCoral : AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_isBusyAction) return;
    setState(() => _isBusyAction = true);
    try {
      await action();
      if (successMessage != null) {
        _showSnack(successMessage);
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isBusyAction = false);
      }
    }
  }

  Future<void> _confirmClearQueue(int count) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Clear Up Next Queue',
      message:
          'Remove all $count song(s) waiting in Up Next? The currently playing song will finish uninterrupted, then Channel 6 will resume shuffle playback.',
      confirmLabel: 'Clear Queue',
      isDestructive: true,
      icon: Icons.playlist_remove_rounded,
    );
    if (!confirmed) return;

    await _runAction(
      () => ref.read(channel6ScheduleProvider.notifier).clearQueue(),
      successMessage:
          'Up Next queue cleared. Shuffle fallback resumes after the current song.',
    );
  }

  Future<void> _openAddSongsSheet() async {
    final addedCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _AddSongsModalSheet(),
    );

    if (addedCount != null && addedCount > 0) {
      _showSnack(
        'Added $addedCount ${addedCount == 1 ? 'song' : 'songs'} to Channel 6 Up Next.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    if (!authState.isAuthenticated || !authState.isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: Colors.white,
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(RouteNames.home),
          ),
          title: const Text(
            'Channel 6 Queue',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 48,
                  color: AppColors.accentCoral,
                ),
                SizedBox(height: 12),
                Text(
                  'Administrator Privileges Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Only authenticated admins can manage the Channel 6 Up Next queue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final scheduleAsync = ref.watch(channel6ScheduleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: Colors.white,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.adminStations);
            }
          },
        ),
        title: const Text(
          'Channel 6 Queue',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.folder_copy_outlined,
              color: AppColors.textSecondary,
              size: 21,
            ),
            tooltip: 'Rescan Local Music Folder',
            onPressed: _isBusyAction
                ? null
                : () => _runAction(
                      () => ref
                          .read(channel6ScheduleProvider.notifier)
                          .rescanLibrary(),
                      successMessage: 'Rescanned Channel 6 local music folder.',
                    ),
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
            tooltip: 'Refresh Live Queue',
            onPressed: () =>
                ref.read(channel6ScheduleProvider.notifier).refresh(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: scheduleAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: AppColors.accentCoral,
                    size: 44,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Unable to Load Channel 6 Queue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(channel6ScheduleProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (schedule) => _buildContent(schedule),
        ),
      ),
    );
  }

  Widget _buildContent(Channel6ScheduleState schedule) {
    final waitingCount = schedule.queue.length;
    final waitingLabel =
        waitingCount == 1 ? '1 waiting' : '$waitingCount waiting';

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => ref.read(channel6ScheduleProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // 1. Currently Playing Card
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            sliver: SliverToBoxAdapter(
              child: _NowPlayingQueueCard(schedule: schedule),
            ),
          ),

          // 2. Up Next Header + Waiting Count + Add Songs Button + Clear
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'Up Next',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: waitingCount > 0
                                    ? AppColors.brandGreenDark
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: waitingCount > 0
                                      ? AppColors.primary.withValues(alpha: 0.45)
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                waitingLabel,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: waitingCount > 0
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _isBusyAction ? null : _openAddSongsSheet,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 17,
                                  color: Colors.black,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Add Songs',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (schedule.queue.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Drag handle or tap arrows to set exact play order',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isBusyAction
                              ? null
                              : () => _confirmClearQueue(schedule.queue.length),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.clear_all_rounded,
                            size: 16,
                            color: AppColors.accentCoral,
                          ),
                          label: const Text(
                            'Clear',
                            style: TextStyle(
                              color: AppColors.accentCoral,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. Reorderable Up Next Queue or Empty Fallback Notice
          if (schedule.queue.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shuffle_rounded,
                          color: AppColors.accentAmber,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Up Next Queue Is Empty',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Channel 6 is shuffling and repeating tracks from the local music folder automatically. Add songs to play your chosen order next.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _isBusyAction ? null : _openAddSongsSheet,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                        ),
                        icon: const Icon(Icons.playlist_add_rounded, size: 18),
                        label: Text(
                          'Browse ${schedule.library.length} Local Songs',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverReorderableList(
                itemCount: schedule.queue.length,
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    elevation: 6,
                    shadowColor: Colors.black,
                    child: child,
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  _runAction(
                    () => ref
                        .read(channel6ScheduleProvider.notifier)
                        .reorder(oldIndex, newIndex),
                  );
                },
                itemBuilder: (context, index) {
                  final item = schedule.queue[index];
                  return Padding(
                    key: ValueKey(item.itemId),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _QueuedTrackCard(
                      item: item,
                      index: index,
                      totalCount: schedule.queue.length,
                      disabled: _isBusyAction,
                      onMoveUp: index > 0
                          ? () => _runAction(
                                () => ref
                                    .read(channel6ScheduleProvider.notifier)
                                    .reorder(index, index - 1),
                              )
                          : null,
                      onMoveDown: index < schedule.queue.length - 1
                          ? () => _runAction(
                                () => ref
                                    .read(channel6ScheduleProvider.notifier)
                                    .reorder(index, index + 2),
                              )
                          : null,
                      onRemove: () => _runAction(
                        () => ref
                            .read(channel6ScheduleProvider.notifier)
                            .removeItem(item.itemId),
                        successMessage: 'Removed "${item.title}" from Up Next.',
                      ),
                    ),
                  );
                },
              ),
            ),

            // 4. Automatic Shuffle Fallback Footer
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.shuffle_rounded,
                        size: 18,
                        color: AppColors.accentAmber,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'After Up Next finishes: Shuffle & Repeat Fallback resumes automatically.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatSeconds(double totalSeconds) {
  final clamped = totalSeconds.isFinite && totalSeconds > 0
      ? totalSeconds.floor()
      : 0;
  final mins = (clamped ~/ 60).toString().padLeft(2, '0');
  final secs = (clamped % 60).toString().padLeft(2, '0');
  return '$mins:$secs';
}

class _NowPlayingQueueCard extends StatelessWidget {
  final Channel6ScheduleState schedule;

  const _NowPlayingQueueCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final isAdminMode = schedule.isAdminScheduleMode;
    final current = schedule.currentTrack;
    final currentIsAdmin = schedule.isCurrentFromAdminSchedule;

    final double progress = (current != null && current.durationSeconds > 0)
        ? (schedule.elapsedSeconds / current.durationSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdminMode
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'CURRENTLY PLAYING',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: currentIsAdmin
                      ? AppColors.brandGreenDark
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: currentIsAdmin
                        ? AppColors.primary.withValues(alpha: 0.6)
                        : AppColors.accentAmber.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      currentIsAdmin
                          ? Icons.queue_music_rounded
                          : Icons.shuffle_rounded,
                      size: 13,
                      color: currentIsAdmin
                          ? AppColors.primary
                          : AppColors.accentAmber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currentIsAdmin ? 'Up Next Queue' : 'Shuffle Fallback',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: currentIsAdmin
                            ? AppColors.primary
                            : AppColors.accentAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current?.title ?? 'No active track',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        current != null
                            ? current.artist
                            : 'Local music folder is empty',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (current != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${_formatSeconds(schedule.elapsedSeconds)} / ${current.durationFormatted}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (current != null) ...[
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3.5,
                      backgroundColor: AppColors.surfaceHighlight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Icon(
                schedule.isScheduleQueuedNext
                    ? Icons.skip_next_rounded
                    : Icons.lock_clock_rounded,
                size: 14,
                color: schedule.isScheduleQueuedNext
                    ? AppColors.primary
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  schedule.isScheduleQueuedNext
                      ? 'Up Next queue begins automatically when this song ends.'
                      : 'Queue edits never interrupt the currently playing song.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: schedule.isScheduleQueuedNext
                        ? AppColors.primaryLight
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QueuedTrackCard extends StatelessWidget {
  final Channel6QueueItem item;
  final int index;
  final int totalCount;
  final bool disabled;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onRemove;

  const _QueuedTrackCard({
    required this.item,
    required this.index,
    required this.totalCount,
    required this.disabled,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: item.available
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.accentCoral.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            enabled: !disabled && totalCount > 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Icon(
                Icons.drag_handle_rounded,
                color: totalCount > 1
                    ? AppColors.textSecondary
                    : AppColors.textDisabled,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandGreenDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: item.available
                              ? Colors.white
                              : AppColors.accentCoral,
                        ),
                      ),
                    ),
                    if (!item.available) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'Missing',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.accentCoral,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.artist} · ${item.durationFormatted}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
            color: onMoveUp != null && !disabled
                ? Colors.white
                : AppColors.textDisabled,
            tooltip: 'Move Up',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: disabled ? null : onMoveUp,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            color: onMoveDown != null && !disabled
                ? Colors.white
                : AppColors.textDisabled,
            tooltip: 'Move Down',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: disabled ? null : onMoveDown,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            color: AppColors.accentCoral,
            tooltip: 'Remove from Queue',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: disabled ? null : onRemove,
          ),
        ],
      ),
    );
  }
}

class _AddSongsModalSheet extends ConsumerStatefulWidget {
  const _AddSongsModalSheet();

  @override
  ConsumerState<_AddSongsModalSheet> createState() =>
      _AddSongsModalSheetState();
}

class _AddSongsModalSheetState extends ConsumerState<_AddSongsModalSheet> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _selectedTrackIds = [];
  String _searchQuery = '';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelected(String trackId) {
    if (_isSubmitting) return;
    setState(() {
      if (_selectedTrackIds.contains(trackId)) {
        _selectedTrackIds.remove(trackId);
      } else {
        _selectedTrackIds.add(trackId);
      }
    });
  }

  Future<void> _submitSelected() async {
    if (_selectedTrackIds.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final count = _selectedTrackIds.length;
      await ref
          .read(channel6ScheduleProvider.notifier)
          .enqueueTracks(List<String>.from(_selectedTrackIds));
      if (mounted) {
        Navigator.of(context).pop(count);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _quickAddSingle(Channel6LibraryTrack track) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(channel6ScheduleProvider.notifier).enqueueTrack(track.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${track.title}" to Up Next.'),
            backgroundColor: AppColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = ref.watch(channel6ScheduleProvider).asData?.value;
    final library = scheduleState?.library ?? const <Channel6LibraryTrack>[];
    final queue = scheduleState?.queue ?? const <Channel6QueueItem>[];

    final queuedCounts = <String, int>{};
    for (final item in queue) {
      queuedCounts[item.trackId] = (queuedCounts[item.trackId] ?? 0) + 1;
    }

    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? library
        : library.where((t) {
            return t.title.toLowerCase().contains(query) ||
                t.artist.toLowerCase().contains(query) ||
                t.album.toLowerCase().contains(query);
          }).toList();

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Songs to Channel 6',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${library.length} songs indexed from local folder',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.folder_copy_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    tooltip: 'Rescan Local Music Folder',
                    onPressed: _isSubmitting
                        ? null
                        : () => ref
                            .read(channel6ScheduleProvider.notifier)
                            .rescanLibrary(),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search local songs...',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.textMuted,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),

            // Indexed Library Song List
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No local songs match your search.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final track = filtered[index];
                        final selectionOrder =
                            _selectedTrackIds.indexOf(track.id);
                        final isSelected = selectionOrder != -1;
                        final queuedCount = queuedCounts[track.id] ?? 0;

                        return InkWell(
                          onTap: () => _toggleSelected(track.id),
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.brandGreenDark
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.7)
                                    : AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Text(
                                          '${selectionOrder + 1}',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.music_note_rounded,
                                          size: 14,
                                          color: AppColors.textMuted,
                                        ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${track.artist} · ${track.durationFormatted}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (queuedCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      '×$queuedCount',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _isSubmitting
                                      ? null
                                      : () => _quickAddSingle(track),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceElevated,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Bottom Multi-Add Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _selectedTrackIds.isEmpty
                        ? const Text(
                            'Tap rows to select multiple, or + for 1 song',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : Row(
                            children: [
                              Text(
                                '${_selectedTrackIds.length} selected',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              TextButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => setState(_selectedTrackIds.clear),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: (_selectedTrackIds.isEmpty || _isSubmitting)
                        ? null
                        : _submitSelected,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.surfaceElevated,
                      foregroundColor: Colors.black,
                      disabledForegroundColor: AppColors.textMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.playlist_add_rounded, size: 18),
                    label: Text(
                      _selectedTrackIds.isEmpty
                          ? 'Add Selected'
                          : 'Add ${_selectedTrackIds.length} to Queue',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
