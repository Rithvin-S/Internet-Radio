import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:pulsecast/features/library/presentation/providers/listener_library_providers.dart';
import 'package:pulsecast/features/admin/domain/models/admin_schedule.dart';
import 'package:pulsecast/features/admin/domain/models/schedule_playlist_track.dart';
import '../providers/admin_providers.dart';
import '../widgets/confirm_dialog.dart';

class AdminSchedulePlaylistScreen extends ConsumerStatefulWidget {
  final int scheduleId;
  final AdminSchedule? schedule;

  const AdminSchedulePlaylistScreen({
    super.key,
    required this.scheduleId,
    this.schedule,
  });

  @override
  ConsumerState<AdminSchedulePlaylistScreen> createState() =>
      _AdminSchedulePlaylistScreenState();
}

class _AdminSchedulePlaylistScreenState
    extends ConsumerState<AdminSchedulePlaylistScreen> {
  Future<void> _handleDeleteTrack(SchedulePlaylistTrack track) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove Track from Playlist',
      message:
          'Remove "${track.title}" from this schedule playlist? The original song in the library will remain untouched.',
      confirmLabel: 'Remove Track',
      isDestructive: true,
      icon: Icons.playlist_remove_rounded,
    );

    if (!confirmed || !mounted) return;

    try {
      final repo = ref.read(adminScheduleRepositoryProvider);
      final trackIdentifier = track.id ?? track.songId ?? track.trackId?.toString() ?? '';
      await repo.deletePlaylistTrack(widget.scheduleId, trackIdentifier);

      ref.invalidate(schedulePlaylistProvider(widget.scheduleId));
      ref.invalidate(adminSchedulesListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${track.title}" from playlist.'),
            backgroundColor: AppColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove track: $e'),
            backgroundColor: AppColors.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openAddTrackDialog(List<SchedulePlaylistTrack> currentTracks) async {
    // Show modal allowing selection from Supabase or General Library
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AddTrackModal(
        onTrackSelected: (selectedTrack) async {
          Navigator.of(sheetContext).pop();
          try {
            final updatedTracks = List<SchedulePlaylistTrack>.from(currentTracks);
            final newOrder = updatedTracks.length + 1;

            final trackToAdd = SchedulePlaylistTrack(
              songId: selectedTrack.songId,
              trackId: selectedTrack.trackId,
              source: selectedTrack.source,
              title: selectedTrack.title,
              artist: selectedTrack.artist,
              album: selectedTrack.album,
              duration: selectedTrack.duration,
              durationSeconds: selectedTrack.durationSeconds,
              playOrder: newOrder,
            );

            updatedTracks.add(trackToAdd);

            final repo = ref.read(adminScheduleRepositoryProvider);
            await repo.updatePlaylistTracks(widget.scheduleId, updatedTracks);

            ref.invalidate(schedulePlaylistProvider(widget.scheduleId));
            ref.invalidate(adminSchedulesListProvider);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added "${trackToAdd.title}" to playlist!'),
                  backgroundColor: AppColors.surfaceElevated,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to add track: $e'),
                  backgroundColor: AppColors.accentCoral,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _handleReorder(
    int oldIndex,
    int newIndex,
    List<SchedulePlaylistTrack> tracks,
  ) async {
    final updatedList = List<SchedulePlaylistTrack>.from(tracks);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = updatedList.removeAt(oldIndex);
    updatedList.insert(newIndex, item);

    // Re-index play order
    final reordered = <SchedulePlaylistTrack>[];
    for (var i = 0; i < updatedList.length; i++) {
      final t = updatedList[i];
      reordered.add(
        SchedulePlaylistTrack(
          id: t.id,
          scheduleId: widget.scheduleId,
          songId: t.songId,
          trackId: t.trackId,
          source: t.source,
          title: t.title,
          artist: t.artist,
          album: t.album,
          duration: t.duration,
          durationSeconds: t.durationSeconds,
          playOrder: i + 1,
        ),
      );
    }

    try {
      final repo = ref.read(adminScheduleRepositoryProvider);
      await repo.updatePlaylistTracks(widget.scheduleId, reordered);
      ref.invalidate(schedulePlaylistProvider(widget.scheduleId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save track order: $e'),
            backgroundColor: AppColors.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistAsync = ref.watch(schedulePlaylistProvider(widget.scheduleId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Schedule Playlist'),
            if (widget.schedule != null)
              Text(
                widget.schedule!.title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Playlist',
            onPressed: () =>
                ref.invalidate(schedulePlaylistProvider(widget.scheduleId)),
          ),
        ],
      ),
      floatingActionButton: playlistAsync.when(
        data: (tracks) => FloatingActionButton.extended(
          onPressed: () => _openAddTrackDialog(tracks),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.playlist_add_rounded),
          label: const Text(
            'Add Track',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        loading: () => null,
        error: (_, __) => null,
      ),
      body: SafeArea(
        child: playlistAsync.when(
          data: (tracks) {
            if (tracks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.queue_music_rounded,
                      size: 56,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tracks assigned to this broadcast schedule.',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add tracks from Supabase Storage or General Library below.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingLarge,
                AppDimensions.paddingSmall,
                AppDimensions.paddingLarge,
                80,
              ),
              itemCount: tracks.length,
              onReorder: (oldIndex, newIndex) =>
                  _handleReorder(oldIndex, newIndex, tracks),
              itemBuilder: (context, index) {
                final track = tracks[index];
                final isSupabase = track.isSupabase;

                return Container(
                  key: ValueKey(track.id ?? '${track.title}_$index'),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      // Play Order Badge
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHighlight,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Track Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // Source Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSupabase
                                        ? AppColors.accentCyan.withValues(alpha: 0.2)
                                        : AppColors.accentAmber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isSupabase ? 'SUPABASE (UUID)' : 'GENERAL (INT)',
                                    style: TextStyle(
                                      color: isSupabase
                                          ? AppColors.accentCyan
                                          : AppColors.accentAmber,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (track.duration != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    track.formattedDuration,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Delete Track Button
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: AppColors.accentCoral,
                          size: 20,
                        ),
                        tooltip: 'Remove Track',
                        onPressed: () => _handleDeleteTrack(track),
                      ),

                      // Drag handle icon
                      const Icon(
                        Icons.drag_handle_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Center(
            child: Text(
              'Failed to load playlist: $e',
              style: const TextStyle(color: AppColors.accentCoral),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal for adding tracks from Supabase or General Library
class _AddTrackModal extends ConsumerStatefulWidget {
  final ValueChanged<SchedulePlaylistTrack> onTrackSelected;

  const _AddTrackModal({required this.onTrackSelected});

  @override
  ConsumerState<_AddTrackModal> createState() => _AddTrackModalState();
}

class _AddTrackModalState extends ConsumerState<_AddTrackModal> {
  int _selectedTab = 0; // 0 = Supabase Library, 1 = General Library

  @override
  Widget build(BuildContext context) {
    final supabaseSongsAsync = ref.watch(adminSongsListProvider);
    final generalTracksAsync = ref.watch(listenerTracksProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLarge),
        ),
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Select Track for Playlist',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Source Switcher (Supabase vs General)
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Supabase Library (Storage)'),
                  selected: _selectedTab == 0,
                  onSelected: (val) => setState(() => _selectedTab = 0),
                  selectedColor: AppColors.accentCyan.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _selectedTab == 0
                        ? AppColors.accentCyan
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('General Library (Radio)'),
                  selected: _selectedTab == 1,
                  onSelected: (val) => setState(() => _selectedTab = 1),
                  selectedColor: AppColors.accentAmber.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _selectedTab == 1
                        ? AppColors.accentAmber
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _selectedTab == 0
                ? supabaseSongsAsync.when(
                    data: (songs) {
                      if (songs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No Supabase songs uploaded yet.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: songs.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: AppColors.borderSubtle),
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.cloud_done_rounded,
                              color: AppColors.accentCyan,
                            ),
                            title: Text(
                              song.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${song.artist} • ${song.formattedDuration}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: AppColors.primary,
                            ),
                            onTap: () {
                              widget.onTrackSelected(
                                SchedulePlaylistTrack(
                                  songId: song.id, // UUID v4
                                  source: 'supabase',
                                  title: song.title,
                                  artist: song.artist,
                                  album: song.album,
                                  duration: song.duration,
                                  durationSeconds: song.durationSeconds,
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  )
                : generalTracksAsync.when(
                    data: (tracks) {
                      if (tracks.isEmpty) {
                        return const Center(
                          child: Text(
                            'No General tracks available.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: tracks.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: AppColors.borderSubtle),
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.radio_rounded,
                              color: AppColors.accentAmber,
                            ),
                            title: Text(
                              track.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${track.artist} • ${track.stationName}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: AppColors.primary,
                            ),
                            onTap: () {
                              widget.onTrackSelected(
                                SchedulePlaylistTrack(
                                  trackId: track.id, // Integer ID
                                  source: 'general',
                                  title: track.title,
                                  artist: track.artist,
                                  album: track.album,
                                  duration: track.duration,
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
          ),
        ],
      ),
    );
  }
}
