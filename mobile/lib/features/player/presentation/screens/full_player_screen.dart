import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/features/favorites/domain/models/favorite_song.dart';
import 'package:pulsecast/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:pulsecast/core/constants/app_colors.dart';
import 'package:pulsecast/core/constants/app_dimensions.dart';
import 'package:pulsecast/core/theme/app_typography.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import 'package:pulsecast/features/stations/presentation/providers/stations_provider.dart';
import 'package:pulsecast/features/player/presentation/providers/player_providers.dart';
import 'package:pulsecast/features/player/presentation/providers/player_state.dart';

class FullPlayerScreen extends ConsumerWidget {
  const FullPlayerScreen({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FullPlayerScreen(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerNotifierProvider);
    final station = playerState.currentStation;
    final nowPlaying = playerState.nowPlaying;
    final status = playerState.status;
    final isPlaying = playerState.isPlaying;
    final isLoading = playerState.isLoading;
    final isReconnecting = playerState.isReconnecting;
    final hasError = playerState.hasError;

    final isStationFavorite =
        station != null ? ref.watch(isStationFavoriteProvider(station.id)) : false;

    if (station == null) {
      return Container(
        height: 300,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(
          child: Text(
            'No station currently selected.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final hasArtwork = station.artworkUrl != null &&
        station.artworkUrl!.startsWith('http');

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXLarge),
        ),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Drag Handle & Collapse Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMedium,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  // Station Genre Pill
                  if (station.genre != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusFull),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(
                          station.genre!.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.accentCyan,
                            letterSpacing: 1,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      isStationFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 22,
                    ),
                    color: isStationFavorite
                        ? AppColors.accentCoral
                        : AppColors.textSecondary,
                    onPressed: () {
                      ref
                          .read(favoritesProvider.notifier)
                          .toggleFavoriteStation(station);
                    },
                    tooltip: isStationFavorite
                        ? 'Remove from Favorites'
                        : 'Add to Favorites',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    color: AppColors.textSecondary,
                    onPressed: () {
                      ref
                          .read(playerNotifierProvider.notifier)
                          .refreshNowPlaying();
                    },
                    tooltip: 'Refresh Metadata',
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingLarge,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // Large Album / Station Artwork with Soft Glow Shadow
                    Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusXLarge),
                          gradient: AppColors.auroraGradient,
                          boxShadow: [
                            BoxShadow(
                              color: isPlaying
                                  ? AppColors.accentCyan.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.4),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusXLarge,
                          ),
                          child: hasArtwork
                              ? CachedNetworkImage(
                                  imageUrl: station.artworkUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => _buildLargeFallbackIcon(),
                                  errorWidget: (_, __, ___) => _buildLargeFallbackIcon(),
                                )
                              : _buildLargeFallbackIcon(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingLarge),

                    // LIVE Badge & Connection Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: isPlaying
                                ? AppColors.liveBadgeGradient
                                : null,
                            color: isPlaying ? null : AppColors.surfaceElevated,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isPlaying
                                      ? Colors.white
                                      : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LIVE',
                                style: AppTypography.liveBadge,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getStatusText(status),
                          style: AppTypography.bodySmall.copyWith(
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.paddingMedium),

                    // Station Name
                    Text(
                      station.name,
                      textAlign: TextAlign.center,
                      style: AppTypography.displayMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Now Playing Song Title / Program Title
                    Text(
                      nowPlaying?.displayTitle ?? 'Live Radio Broadcast',
                      textAlign: TextAlign.center,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (nowPlaying?.displaySubtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        nowPlaying!.displaySubtitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (nowPlaying != null && nowPlaying.hasTrackMetadata) ...[
                      const SizedBox(height: 10),
                      Builder(builder: (context) {
                        final songFavId = 'general_${station.id}_${nowPlaying.title.hashCode}';
                        final isSongFav = ref.watch(isSongFavoriteProvider(songFavId));
                        return InkWell(
                          onTap: () {
                            ref.read(favoritesProvider.notifier).toggleFavoriteSong(
                                  FavoriteSong(
                                    id: songFavId,
                                    source: 'general',
                                    trackId: nowPlaying.title.hashCode.abs(),
                                    title: nowPlaying.title ?? 'Live Track',
                                    artist: nowPlaying.artist ?? station.name,
                                    album: nowPlaying.album,
                                    stationId: station.id,
                                    stationName: station.name,
                                    duration: nowPlaying.duration,
                                    favoritedAt: DateTime.now(),
                                  ),
                                );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSongFav
                                  ? AppColors.accentCoral.withValues(alpha: 0.15)
                                  : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSongFav
                                    ? AppColors.accentCoral.withValues(alpha: 0.4)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSongFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 14,
                                  color: isSongFav ? AppColors.accentCoral : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isSongFav ? 'Favorited Track' : 'Save Song to Favorites',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSongFav ? AppColors.accentCoral : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: AppDimensions.paddingLarge),

                    // Error Notification & Retry Action
                    if (hasError && playerState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                        decoration: BoxDecoration(
                          color: AppColors.accentCoral.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMedium,
                          ),
                          border: Border.all(
                            color: AppColors.accentCoral.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.accentCoral,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                playerState.errorMessage!,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.accentCoral,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ref
                                    .read(playerNotifierProvider.notifier)
                                    .playStation(station);
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.paddingMedium),
                    ],

                    // Player Control Buttons (Stop, Play/Pause, Station Switching)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.paddingMedium,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous Station Button
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded),
                            iconSize: 34,
                            color: AppColors.textSecondary,
                            onPressed: () => _switchStation(ref, station, false),
                            tooltip: 'Previous Station',
                          ),
                          const SizedBox(width: AppDimensions.space16),

                          // Stop Button
                          IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surfaceHighlight,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(14),
                            ),
                            icon: const Icon(Icons.stop_rounded),
                            iconSize: 26,
                            onPressed: () {
                              ref
                                  .read(playerNotifierProvider.notifier)
                                  .stop();
                              Navigator.of(context).pop();
                            },
                            tooltip: 'Stop Radio',
                          ),
                          const SizedBox(width: AppDimensions.space20),

                          // Large Play / Pause Primary Button
                          GestureDetector(
                            onTap: (isLoading || isReconnecting)
                                ? null
                                : () {
                                    ref
                                        .read(playerNotifierProvider.notifier)
                                        .togglePlayPause();
                                  },
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isPlaying
                                    ? AppColors.auroraGradient
                                    : null,
                                color: isPlaying
                                    ? null
                                    : AppColors.surfaceElevated,
                                border: Border.all(
                                  color: AppColors.accentCyan,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accentCyan
                                        .withValues(alpha: 0.3),
                                    blurRadius: 18,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: (isLoading || isReconnecting)
                                  ? const Center(
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 38,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.space20),

                          // Next Station Button
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded),
                            iconSize: 34,
                            color: AppColors.textSecondary,
                            onPressed: () => _switchStation(ref, station, true),
                            tooltip: 'Next Station',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingMedium),

                    // Up Next / Scheduled Playlist Section
                    if (nowPlaying != null && nowPlaying.upNext.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Up Next on ${station.name}',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.paddingSmall),
                      ...nowPlaying.upNext.take(4).map(
                            (track) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.paddingMedium,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardSurface,
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMedium,
                                ),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.queue_music_rounded,
                                    color: AppColors.textMuted,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.title,
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (track.artist != null)
                                          Text(
                                            track.artist!,
                                            style: AppTypography.caption
                                                .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (track.duration != null)
                                    Text(
                                      track.duration!,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      const SizedBox(height: AppDimensions.paddingLarge),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _switchStation(WidgetRef ref, Station current, bool next) {
    final stations = ref.read(stationsListProvider).value ?? [];
    if (stations.isEmpty) return;

    final currentIndex = stations.indexWhere((s) => s.id == current.id);
    if (currentIndex == -1) return;

    int newIndex;
    if (next) {
      newIndex = (currentIndex + 1) % stations.length;
    } else {
      newIndex = (currentIndex - 1 + stations.length) % stations.length;
    }

    ref.read(playerNotifierProvider.notifier).playStation(stations[newIndex]);
  }

  Widget _buildLargeFallbackIcon() {
    return const Center(
      child: Icon(
        Icons.radio_rounded,
        color: Colors.white,
        size: 96,
      ),
    );
  }

  String _getStatusText(RadioPlaybackStatus status) {
    switch (status) {
      case RadioPlaybackStatus.playing:
        return 'Connected • High Fidelity Stream';
      case RadioPlaybackStatus.buffering:
        return 'Buffering live stream...';
      case RadioPlaybackStatus.loading:
        return 'Connecting to radio stream...';
      case RadioPlaybackStatus.reconnecting:
        return 'Reconnecting to live stream...';
      case RadioPlaybackStatus.paused:
        return 'Stream Paused';
      case RadioPlaybackStatus.error:
        return 'Stream Connection Error';
      case RadioPlaybackStatus.idle:
        return 'Ready to Stream';
    }
  }

  Color _getStatusColor(RadioPlaybackStatus status) {
    switch (status) {
      case RadioPlaybackStatus.playing:
        return AppColors.connected;
      case RadioPlaybackStatus.buffering:
      case RadioPlaybackStatus.loading:
      case RadioPlaybackStatus.reconnecting:
        return AppColors.buffering;
      case RadioPlaybackStatus.error:
        return AppColors.accentCoral;
      case RadioPlaybackStatus.paused:
      case RadioPlaybackStatus.idle:
        return AppColors.textSecondary;
    }
  }
}
