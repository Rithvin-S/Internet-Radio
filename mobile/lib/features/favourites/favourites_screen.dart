import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulsecast/core/constants/app_colors.dart';
import 'package:pulsecast/core/constants/app_dimensions.dart';
import 'package:pulsecast/core/theme/app_typography.dart';
import 'package:pulsecast/core/connectivity/connectivity_providers.dart';
import 'package:pulsecast/core/sync/sync_providers.dart';
import 'package:pulsecast/core/sync/sync_queue.dart';
import 'package:pulsecast/features/favorites/domain/models/favorite_song.dart';
import 'package:pulsecast/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:pulsecast/features/player/presentation/providers/player_providers.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import 'package:pulsecast/routing/route_names.dart';

class FavouritesScreen extends ConsumerStatefulWidget {
  const FavouritesScreen({super.key});

  @override
  ConsumerState<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends ConsumerState<FavouritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favState = ref.watch(favoritesProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourites', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            tooltip: 'Settings & Preferences',
            onPressed: () => context.push(RouteNames.settings),
          ),
          // Synchronization status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _buildSyncBadge(syncStatus, isOnline),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTypography.titleMedium.copyWith(fontSize: 14),
          tabs: [
            Tab(text: 'Stations (${favState.favoriteStations.length})'),
            Tab(text: 'Songs (${favState.favoriteSongs.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Favorite Stations
          RefreshIndicator(
            onRefresh: () => ref.read(favoritesProvider.notifier).loadFavorites(),
            color: AppColors.primary,
            child: _buildStationsTab(favState),
          ),

          // Tab 2: Favorite Songs
          RefreshIndicator(
            onRefresh: () => ref.read(favoritesProvider.notifier).loadFavorites(),
            color: AppColors.primary,
            child: _buildSongsTab(favState),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBadge(SyncStatus status, bool isOnline) {
    if (!isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 14, color: AppColors.accentAmber),
            SizedBox(width: 4),
            Text('Offline', style: TextStyle(fontSize: 11, color: AppColors.accentAmber)),
          ],
        ),
      );
    }

    switch (status) {
      case SyncStatus.syncing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
        );
      case SyncStatus.synced:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentEmerald.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.accentEmerald),
              SizedBox(width: 4),
              Text('Synced', style: TextStyle(fontSize: 11, color: AppColors.accentEmerald)),
            ],
          ),
        );
      case SyncStatus.error:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentCoral.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_sync_rounded, size: 14, color: AppColors.accentCoral),
              SizedBox(width: 4),
              Text('Pending', style: TextStyle(fontSize: 11, color: AppColors.accentCoral)),
            ],
          ),
        );
      case SyncStatus.idle:
      case SyncStatus.offline:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStationsTab(FavoritesState favState) {
    if (favState.isLoading && favState.favoriteStations.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
    }

    if (favState.favoriteStations.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  size: 36,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Favorite Stations Yet',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the heart icon on any station to keep your top broadcasts easily accessible.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go(RouteNames.stations),
                icon: const Icon(Icons.radio_rounded, size: 18),
                label: const Text('Explore Stations'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: AppColors.background,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentStation = ref.watch(currentStationProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: favState.favoriteStations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final station = favState.favoriteStations[index];
        final isCurrent = currentStation?.id == station.id;

        return _FavoriteStationCard(
          station: station,
          isCurrent: isCurrent,
          isPlaying: isCurrent && isPlaying,
          onPlay: () {
            ref.read(playerNotifierProvider.notifier).playStation(station);
          },
          onRemove: () {
            ref.read(favoritesProvider.notifier).toggleFavoriteStation(station);
          },
        );
      },
    );
  }

  Widget _buildSongsTab(FavoritesState favState) {
    if (favState.favoriteSongs.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  size: 36,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Favorite Songs Yet',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the heart icon in the Music Library or Player view to save tracks to your personal library.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go(RouteNames.library),
                icon: const Icon(Icons.library_music_rounded, size: 18),
                label: const Text('Browse Library'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: AppColors.background,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: favState.favoriteSongs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final song = favState.favoriteSongs[index];
        return _FavoriteSongCard(
          song: song,
          onRemove: () {
            ref.read(favoritesProvider.notifier).toggleFavoriteSong(song);
          },
        );
      },
    );
  }
}

class _FavoriteStationCard extends StatelessWidget {
  final Station station;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  const _FavoriteStationCard({
    required this.station,
    required this.isCurrent,
    required this.isPlaying,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isCurrent && isPlaying) ? AppColors.primary : AppColors.border,
          width: (isCurrent && isPlaying) ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: onPlay,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 48,
            color: AppColors.surfaceElevated,
            child: station.artworkUrl != null &&
                    station.artworkUrl!.isNotEmpty &&
                    station.artworkUrl!.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: station.artworkUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Icon(
                      Icons.radio_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.radio_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  )
                : const Icon(
                    Icons.radio_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
          ),
        ),
        title: Text(
          station.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          station.genre ?? '24/7 Live Radio',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 23),
          tooltip: 'Remove from Favourites',
          onPressed: onRemove,
        ),
      ),
    );
  }
}

class _FavoriteSongCard extends StatelessWidget {
  final FavoriteSong song;
  final VoidCallback onRemove;

  const _FavoriteSongCard({
    required this.song,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: song.isSupabase
                ? AppColors.brandGreenDark
                : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: song.isSupabase
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Icon(
            song.isSupabase ? Icons.cloud_done_rounded : Icons.music_note_rounded,
            color: song.isSupabase ? AppColors.primaryLight : AppColors.primary,
            size: 22,
          ),
        ),
        title: Text(
          song.title,
          style: AppTypography.titleMedium.copyWith(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              song.artist,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: song.isSupabase
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: song.isSupabase
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      song.isSupabase ? 'Storage Library' : (song.stationName ?? 'Radio'),
                      style: TextStyle(
                        fontSize: 10,
                        color: song.isSupabase ? AppColors.primaryLight : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  song.durationFormatted,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite_rounded, color: AppColors.accentCoral, size: 22),
          tooltip: 'Remove from Favorites',
          onPressed: onRemove,
        ),
      ),
    );
  }
}
