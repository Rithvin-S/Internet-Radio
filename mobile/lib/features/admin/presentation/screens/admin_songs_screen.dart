import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../routing/route_names.dart';
import 'package:pulsecast/features/admin/domain/models/admin_song.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_song_edit_dialog.dart';
import '../widgets/admin_song_preview_modal.dart';
import '../widgets/confirm_dialog.dart';

/// Admin Music Library Screen aligned with the exact reference Library UI.
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
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.accentAmber),
                SizedBox(width: 8),
                Expanded(child: Text('Cannot Delete Song')),
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

  Future<void> _handleEditSong(AdminSong song) async {
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
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(adminSongsListProvider);
    final statsAsync = ref.watch(adminSongStatsProvider);
    final activeFilter = ref.watch(adminSongActiveFilterProvider);
    final canPop = context.canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: Colors.white,
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text(
          'Library',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 22),
            tooltip: 'Refresh Library',
            onPressed: () {
              ref.invalidate(adminSongsListProvider);
              ref.invalidate(adminSongStatsProvider);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: GestureDetector(
              onTap: () => context.push(RouteNames.adminSongUpload),
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
            // Search Bar matching Reference Library
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {});
                  ref.read(adminSongSearchProvider.notifier).setQuery(val);
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search tracks...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                            ref.read(adminSongSearchProvider.notifier).setQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),

            // Filter Pills + Compact Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterPill(
                            label: 'All',
                            isSelected: activeFilter == null,
                            onTap: () => ref.read(adminSongActiveFilterProvider.notifier).setFilter(null),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterPill(
                            label: 'Active',
                            isSelected: activeFilter == true,
                            onTap: () => ref.read(adminSongActiveFilterProvider.notifier).setFilter(true),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterPill(
                            label: 'Archived',
                            isSelected: activeFilter == false,
                            onTap: () => ref.read(adminSongActiveFilterProvider.notifier).setFilter(false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  statsAsync.when(
                    data: (stats) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '${stats.totalSongs} tracks • ${stats.formattedTotalStorage}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Songs List matching Reference Track Rows
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
                            padding: EdgeInsets.symmetric(vertical: 72),
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
                                    'No tracks found in library.',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: songs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _buildTrackRow(context, songs[index]);
                      },
                    );
                  },
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
                            Icons.error_outline_rounded,
                            color: AppColors.accentCoral,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load songs: $error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.accentCoral),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(adminSongsListProvider),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTrackRow(BuildContext context, AdminSong song) {
    final subtitleText = song.isActive
        ? '${song.artist} • ${song.formattedDuration}'
        : '${song.artist} • ${song.formattedDuration} • Archived';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          // Artwork / Music Square Thumbnail
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: song.isActive
                  ? AppColors.brandGreenDark
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: song.isActive
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : AppColors.border,
              ),
            ),
            child: Icon(
              Icons.music_note_rounded,
              color: song.isActive ? AppColors.primary : AppColors.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Artist · Duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: song.isActive
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Circular Preview Play Button matching Reference Library row
          InkWell(
            onTap: () => AdminSongPreviewModal.show(context, song),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceElevated,
                border: Border.all(color: AppColors.borderLight, width: 1.2),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),

          // 3-dot Menu matching Reference Library row
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            color: AppColors.surfaceElevated,
            onSelected: (value) {
              switch (value) {
                case 'preview':
                  AdminSongPreviewModal.show(context, song);
                  break;
                case 'edit':
                  _handleEditSong(song);
                  break;
                case 'delete':
                  _handleDeleteSong(song);
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'preview',
                child: Row(
                  children: [
                    Icon(Icons.headphones_rounded, color: AppColors.primary, size: 18),
                    SizedBox(width: 10),
                    Text('Preview Track'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text('Edit Metadata'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppColors.accentCoral, size: 18),
                    SizedBox(width: 10),
                    Text('Delete Song', style: TextStyle(color: AppColors.accentCoral)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
