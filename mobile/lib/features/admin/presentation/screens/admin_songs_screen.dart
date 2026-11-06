import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../routing/route_names.dart';
import 'package:pulsecast/features/admin/domain/models/admin_song.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_song_edit_dialog.dart';
import '../widgets/admin_song_preview_modal.dart';
import '../widgets/confirm_dialog.dart';

class AdminSongsScreen extends ConsumerStatefulWidget {
  const AdminSongsScreen({super.key});

  @override
  ConsumerState<AdminSongsScreen> createState() => _AdminSongsScreenState();
}

class _AdminSongsScreenState extends ConsumerState<AdminSongsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteSong(AdminSong song) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Song',
      message:
          'Are you sure you want to permanently delete "${song.title}" from Supabase Storage and database? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );

    if (!confirmed || !mounted) return;

    try {
      final repo = ref.read(adminSongRepositoryProvider);
      await repo.deleteSong(song.id, permanent: true);

      ref.invalidate(adminSongsListProvider);
      ref.invalidate(adminSongStatsProvider);
      ref.invalidate(adminDashboardStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Song "${song.title}" deleted.'),
            backgroundColor: AppColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // Backend schedule conflict error
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.accentAmber),
                SizedBox(width: 8),
                Text('Cannot Delete Song'),
              ],
            ),
            content: Text(
              e.message.isNotEmpty
                  ? e.message
                  : 'This song is currently assigned to one or more active program schedules. Archive it instead or remove it from schedules first.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.message}'),
            backgroundColor: AppColors.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(adminSongsListProvider);
    final statsAsync = ref.watch(adminSongStatsProvider);
    final activeFilter = ref.watch(adminSongActiveFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Music Library'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Library',
            onPressed: () {
              ref.invalidate(adminSongsListProvider);
              ref.invalidate(adminSongStatsProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.adminSongUpload),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.cloud_upload_rounded),
        label: const Text(
          'Upload Song',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stats summary header
            statsAsync.when(
              data: (stats) => Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingLarge,
                  vertical: 4,
                ),
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      'Songs',
                      '${stats.totalSongs}',
                      AppColors.primary,
                    ),
                    const VerticalDivider(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                    _buildSummaryItem(
                      'Active',
                      '${stats.activeSongs}',
                      AppColors.accentEmerald,
                    ),
                    const VerticalDivider(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                    _buildSummaryItem(
                      'Storage',
                      stats.formattedTotalStorage,
                      AppColors.accentCyan,
                    ),
                    const VerticalDivider(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                    _buildSummaryItem(
                      'Duration',
                      stats.formattedTotalDuration,
                      AppColors.accentAmber,
                    ),
                  ],
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingLarge,
                vertical: AppDimensions.paddingSmall,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  ref.read(adminSongSearchProvider.notifier).setQuery(val);
                },
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(adminSongSearchProvider.notifier)
                                .setQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.cardSurface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMedium,
                    vertical: AppDimensions.paddingSmall,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
              ),
            ),

            // Active / Archived Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingLarge,
              ),
              child: Row(
                children: [
                  _buildChip(
                    label: 'All Songs',
                    isSelected: activeFilter == null,
                    onTap: () => ref
                        .read(adminSongActiveFilterProvider.notifier)
                        .setFilter(null),
                  ),
                  const SizedBox(width: 8),
                  _buildChip(
                    label: 'Active Only',
                    isSelected: activeFilter == true,
                    onTap: () => ref
                        .read(adminSongActiveFilterProvider.notifier)
                        .setFilter(true),
                  ),
                  const SizedBox(width: 8),
                  _buildChip(
                    label: 'Archived',
                    isSelected: activeFilter == false,
                    onTap: () => ref
                        .read(adminSongActiveFilterProvider.notifier)
                        .setFilter(false),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Songs List
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () async {
                  ref.invalidate(adminSongsListProvider);
                  ref.invalidate(adminSongStatsProvider);
                  await ref.read(adminSongsListProvider.future);
                },
                child: songsAsync.when(
                  data: (songs) {
                    if (songs.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.queue_music_rounded,
                                    size: 48,
                                    color: AppColors.textMuted,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No songs found in Supabase Storage library.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
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
                        80, // room for FAB
                      ),
                      itemCount: songs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppDimensions.paddingSmall),
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return _buildSongCard(context, song);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (error, _) => Center(
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
                          'Failed to load songs: $error',
                          style: const TextStyle(color: AppColors.accentCoral),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(adminSongsListProvider),
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

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: isSelected
          ? AppColors.primary.withValues(alpha: 0.2)
          : AppColors.cardSurface,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.borderSubtle,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildSongCard(BuildContext context, AdminSong song) {
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentViolet.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: AppColors.accentViolet,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.album != null && song.album!.isNotEmpty
                          ? '${song.artist} • ${song.album}'
                          : song.artist,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: song.isActive
                      ? AppColors.accentEmerald.withValues(alpha: 0.2)
                      : AppColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  song.isActive ? 'ACTIVE' : 'ARCHIVED',
                  style: TextStyle(
                    color: song.isActive
                        ? AppColors.accentEmerald
                        : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 8),

          // Metadata row & Action buttons
          Row(
            children: [
              Text(
                '${song.formattedDuration} • ${song.formattedFileSize}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              // Preview signed URL button
              IconButton(
                icon: const Icon(
                  Icons.headphones_rounded,
                  color: AppColors.accentCyan,
                  size: 20,
                ),
                tooltip: 'Preview (Signed URL)',
                onPressed: () => AdminSongPreviewModal.show(context, song),
              ),
              // Edit metadata button
              IconButton(
                icon: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'Edit Song',
                onPressed: () async {
                  final saved = await AdminSongEditDialog.show(
                    context,
                    song: song,
                    onSave: (id, {title, artist, album, isActive}) async {
                      final repo = ref.read(adminSongRepositoryProvider);
                      await repo.updateSong(
                        id,
                        title: title,
                        artist: artist,
                        album: album,
                        isActive: isActive,
                      );
                    },
                  );
                  if (saved) {
                    ref.invalidate(adminSongsListProvider);
                    ref.invalidate(adminSongStatsProvider);
                  }
                },
              ),
              // Delete button
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.accentCoral,
                  size: 20,
                ),
                tooltip: 'Delete Song',
                onPressed: () => _handleDeleteSong(song),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
