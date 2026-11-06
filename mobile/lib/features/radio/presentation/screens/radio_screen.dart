import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/connectivity/connectivity_providers.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../routing/route_names.dart';
import '../../../favorites/domain/models/favorite_song.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../player/presentation/providers/player_state.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../stations/domain/models/station.dart';
import '../../../stations/presentation/providers/stations_provider.dart';

/// Dedicated Radio-First Screen: Primary landing experience of PulseCast
class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});

  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen> {
  bool _hasCheckedAutoplay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleAutoplay());
  }

  void _handleAutoplay() {
    if (!mounted || _hasCheckedAutoplay) return;
    _hasCheckedAutoplay = true;

    final playerState = ref.read(playerNotifierProvider);
    final settings = ref.read(userSettingsProvider);
    final isOnline = ref.read(isOnlineProvider);

    if (settings.autoplayOnLaunch && isOnline && playerState.status == RadioPlaybackStatus.idle) {
      final target = playerState.currentStation ??
          const Station(
            id: 6,
            name: 'PulseCast Radio',
            description: 'Automated 24/7 internet radio streaming random music from Supabase Storage',
            genre: 'Mixed / Electronic',
            streamUrl: AppConfig.channel6StreamUrl,
            isActive: true,
          );
      ref.read(playerNotifierProvider.notifier).playStation(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerNotifierProvider);
    final station = playerState.currentStation ??
        const Station(
          id: 6,
          name: 'PulseCast Radio',
          description: 'Automated 24/7 internet radio streaming random music from Supabase Storage',
          genre: 'Mixed / Electronic',
          streamUrl: AppConfig.channel6StreamUrl,
          isActive: true,
        );
    final nowPlaying = playerState.nowPlaying;
    final status = playerState.status;
    final isPlaying = playerState.isPlaying;
    final isLoading = playerState.isLoading;
    final isReconnecting = playerState.isReconnecting;
    final hasError = playerState.hasError;
    final stationsAsync = ref.watch(stationsListProvider);

    final isStationFavorite = ref.watch(isStationFavoriteProvider(station.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.auroraGradient,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              child: const Text(
                'PULSE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'CAST',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          _buildConnectivityBadge(ref),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            tooltip: 'Settings',
            onPressed: () => context.push(RouteNames.settings),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingLarge,
            vertical: AppDimensions.paddingMedium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Station Genre Pill
              if (station.genre != null && station.genre!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppDimensions.space12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      station.genre!.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accentCyan,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                // Large Central Radio Artwork
                _buildArtworkCard(station, isPlaying),
                const SizedBox(height: AppDimensions.space16),

                // LIVE Indicator + Status Text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: isPlaying ? AppColors.liveBadgeGradient : null,
                        color: isPlaying ? null : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPlaying ? Colors.white : AppColors.textMuted,
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
                const SizedBox(height: AppDimensions.space12),

                // Station Name
                Text(
                  station.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.displayMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),

                // Now Playing Song Title
                Text(
                  nowPlaying?.displayTitle ?? 'Live Radio Broadcast',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.accentCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                // Artist Subtitle
                if (nowPlaying?.displaySubtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    nowPlaying!.displaySubtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],

                // Favorite Song Action Pill (when song metadata available)
                if (nowPlaying != null && nowPlaying.hasTrackMetadata) ...[
                  const SizedBox(height: AppDimensions.space12),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                            const SizedBox(width: 6),
                            Text(
                              isSongFav ? 'Saved to Favorites' : 'Favorite This Song',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSongFav ? AppColors.accentCoral : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: AppDimensions.space16),

                // Error Notice with Retry Button
                if (hasError && playerState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                    decoration: BoxDecoration(
                      color: AppColors.accentCoral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(color: AppColors.accentCoral.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.accentCoral, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            playerState.errorMessage!,
                            style: AppTypography.caption.copyWith(color: AppColors.accentCoral),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.read(playerNotifierProvider.notifier).playStation(station),
                          child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space16),
                ],

                // Primary Playback Controls
                _buildPlaybackControls(
                  context: context,
                  ref: ref,
                  station: station,
                  isPlaying: isPlaying,
                  isLoading: isLoading,
                  isReconnecting: isReconnecting,
                  isStationFavorite: isStationFavorite,
                ),

              const SizedBox(height: AppDimensions.space24),

              // Station Carousel / Quick Switcher
              _buildStationCarousel(context, ref, stationsAsync, station.id),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectivityBadge(WidgetRef ref) {
    final connStatus = ref.watch(connectivityStatusProvider);
    final Color statusColor;
    final String statusText;
    switch (connStatus) {
      case ConnectivityStatus.online:
        statusColor = AppColors.connected;
        statusText = 'ONLINE';
        break;
      case ConnectivityStatus.serverUnavailable:
        statusColor = AppColors.accentAmber;
        statusText = 'CONNECTING';
        break;
      case ConnectivityStatus.offline:
        statusColor = AppColors.accentCoral;
        statusText = 'OFFLINE';
        break;
      case ConnectivityStatus.checking:
      case ConnectivityStatus.unknown:
        statusColor = AppColors.accentCyan;
        statusText = 'CHECKING';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkCard(Station station, bool isPlaying) {
    final hasArtwork = station.artworkUrl != null && station.artworkUrl!.startsWith('http');

    return Center(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
          gradient: AppColors.auroraGradient,
          boxShadow: [
            BoxShadow(
              color: isPlaying
                  ? AppColors.accentCyan.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.4),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
          child: hasArtwork
              ? CachedNetworkImage(
                  imageUrl: station.artworkUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildLargeFallbackArtwork(station.name, isPlaying),
                  errorWidget: (_, __, ___) => _buildLargeFallbackArtwork(station.name, isPlaying),
                )
              : _buildLargeFallbackArtwork(station.name, isPlaying),
        ),
      ),
    );
  }

  Widget _buildLargeFallbackArtwork(String stationName, bool isPlaying) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle circular sound wave background
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle, width: 2),
            ),
          ),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle, width: 2),
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isPlaying ? AppColors.auroraGradient : null,
              color: isPlaying ? null : AppColors.surfaceHighlight,
            ),
            child: Icon(
              Icons.radio_rounded,
              size: 40,
              color: isPlaying ? Colors.white : AppColors.accentCyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls({
    required BuildContext context,
    required WidgetRef ref,
    required Station station,
    required bool isPlaying,
    required bool isLoading,
    required bool isReconnecting,
    required bool isStationFavorite,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Favorite Station Toggle Button
        IconButton(
          icon: Icon(
            isStationFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 26,
          ),
          color: isStationFavorite ? AppColors.accentCoral : AppColors.textSecondary,
          tooltip: isStationFavorite ? 'Favorited Station' : 'Favorite Station',
          onPressed: () {
            ref.read(favoritesProvider.notifier).toggleFavoriteStation(station);
          },
        ),
        const SizedBox(width: AppDimensions.space12),

        // Skip to Previous Station
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: 34,
          color: AppColors.textSecondary,
          tooltip: 'Previous Station',
          onPressed: () => _switchStation(ref, station, isNext: false),
        ),
        const SizedBox(width: AppDimensions.space16),

        // Giant Play / Pause Primary Button
        GestureDetector(
          onTap: (isLoading || isReconnecting)
              ? null
              : () {
                  ref.read(playerNotifierProvider.notifier).togglePlayPause();
                },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isPlaying ? AppColors.auroraGradient : null,
              color: isPlaying ? null : AppColors.surfaceElevated,
              border: Border.all(color: AppColors.accentCyan, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withValues(alpha: 0.35),
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
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 40,
                    color: isPlaying ? Colors.white : AppColors.accentCyan,
                  ),
          ),
        ),
        const SizedBox(width: AppDimensions.space16),

        // Skip to Next Station
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 34,
          color: AppColors.textSecondary,
          tooltip: 'Next Station',
          onPressed: () => _switchStation(ref, station, isNext: true),
        ),
        const SizedBox(width: AppDimensions.space12),

        // Refresh Now-Playing Metadata
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 24),
          color: AppColors.textSecondary,
          tooltip: 'Refresh Metadata',
          onPressed: () {
            ref.read(playerNotifierProvider.notifier).refreshNowPlaying();
          },
        ),
      ],
    );
  }

  Widget _buildStationCarousel(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Station>> stationsAsync,
    int? currentStationId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Switch Stations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => context.go(RouteNames.stations),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),

        stationsAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accentCyan),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (stations) {
            final activeStations = stations.where((s) => s.isActive).toList();
            if (activeStations.isEmpty) return const SizedBox.shrink();

            return SizedBox(
              height: 135,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: activeStations.length,
                itemBuilder: (context, index) {
                  final s = activeStations[index];
                  final isSelected = s.id == currentStationId;

                  return GestureDetector(
                    onTap: () {
                      if (!isSelected) {
                        ref.read(playerNotifierProvider.notifier).playStation(s);
                      }
                    },
                    child: Container(
                      width: 155,
                      margin: EdgeInsets.only(
                        right: index == activeStations.length - 1 ? 0 : 12,
                        top: 4,
                        bottom: 8,
                      ),
                      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.surfaceElevated : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                        border: Border.all(
                          color: isSelected ? AppColors.accentCyan : AppColors.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.accentCyan.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? AppColors.auroraGradient
                                      : const LinearGradient(
                                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                                        ),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                                ),
                                child: const Icon(
                                  Icons.radio_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentCyan.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'PLAYING',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: AppColors.accentCyan,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? AppColors.accentCyan : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            s.genre ?? 'Live Radio',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _switchStation(WidgetRef ref, Station currentStation, {required bool isNext}) {
    final stationsAsync = ref.read(stationsListProvider);
    stationsAsync.whenData((stations) {
      final active = stations.where((s) => s.isActive).toList();
      if (active.length <= 1) return;

      final currentIndex = active.indexWhere((s) => s.id == currentStation.id);
      if (currentIndex == -1) return;

      final targetIndex = isNext
          ? (currentIndex + 1) % active.length
          : (currentIndex - 1 + active.length) % active.length;

      ref.read(playerNotifierProvider.notifier).playStation(active[targetIndex]);
    });
  }

  String _getStatusText(RadioPlaybackStatus status) {
    switch (status) {
      case RadioPlaybackStatus.idle:
        return 'Ready to Stream';
      case RadioPlaybackStatus.loading:
        return 'Connecting...';
      case RadioPlaybackStatus.buffering:
        return 'Buffering...';
      case RadioPlaybackStatus.playing:
        return 'Streaming Live';
      case RadioPlaybackStatus.paused:
        return 'Paused';
      case RadioPlaybackStatus.reconnecting:
        return 'Reconnecting...';
      case RadioPlaybackStatus.error:
        return 'Offline';
    }
  }

  Color _getStatusColor(RadioPlaybackStatus status) {
    switch (status) {
      case RadioPlaybackStatus.playing:
        return AppColors.connected;
      case RadioPlaybackStatus.buffering:
      case RadioPlaybackStatus.loading:
      case RadioPlaybackStatus.reconnecting:
        return AppColors.accentAmber;
      case RadioPlaybackStatus.error:
        return AppColors.accentCoral;
      case RadioPlaybackStatus.idle:
      case RadioPlaybackStatus.paused:
        return AppColors.textSecondary;
    }
  }
}
