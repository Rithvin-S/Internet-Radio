import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/features/favorites/presentation/providers/favorites_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/station.dart';

class StationCard extends ConsumerWidget {
  final Station station;
  final bool isSelected;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onSelect;
  final VoidCallback onTogglePlay;

  const StationCard({
    super.key,
    required this.station,
    required this.isSelected,
    required this.isPlaying,
    required this.isLoading,
    required this.onSelect,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasArtwork = station.artworkUrl != null &&
        station.artworkUrl!.startsWith('http');
    final isFavorite = ref.watch(isStationFavoriteProvider(station.id));

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.space12),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.surfaceElevated
            : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(
          color: isSelected
              ? AppColors.accentCyan
              : AppColors.borderSubtle,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space12,
              vertical: AppDimensions.space8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Station Artwork (Fixed 52x52)
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? AppColors.auroraGradient
                          : const LinearGradient(
                              colors: [
                                Color(0xFF1E293B),
                                Color(0xFF0F172A),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                    ),
                    child: hasArtwork
                        ? CachedNetworkImage(
                            imageUrl: station.artworkUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildFallbackIcon(),
                            errorWidget: (_, __, ___) => _buildFallbackIcon(),
                          )
                        : _buildFallbackIcon(),
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),

                // 2. Flexible Information Area (Expanded to fit all available remaining space)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Station Name & Optional Fallback Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              station.name,
                              style: AppTypography.titleMedium.copyWith(
                                color: isSelected
                                    ? AppColors.accentCyan
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (station.isLocalFallback) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentAmber
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusSmall,
                                ),
                              ),
                              child: Text(
                                'DEV',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.accentAmber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Genre Tag & LIVE / STREAMING Indicator
                      Row(
                        children: [
                          if (station.genre != null &&
                              station.genre!.isNotEmpty)
                            Flexible(
                              fit: FlexFit.loose,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHighlight
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSmall,
                                  ),
                                ),
                                child: Text(
                                  station.genre!,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          if (station.genre != null &&
                              station.genre!.isNotEmpty &&
                              isSelected)
                            const SizedBox(width: 6),
                          if (isSelected)
                            _buildStatusIndicator(),
                        ],
                      ),

                      // Station Description
                      if (station.description != null &&
                          station.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          station.description!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.space8),

                // 3. Fixed Trailing Control Area (Width: 44px dedicated footprint)
                SizedBox(
                  width: 44,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Favorite Toggle Button
                      SizedBox(
                        width: 38,
                        height: 36,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite
                                ? AppColors.accentCoral
                                : AppColors.textSecondary,
                            size: 22,
                          ),
                          tooltip: isFavorite
                              ? 'Remove from Favorites'
                              : 'Add to Favorites',
                          onPressed: () {
                            ref
                                .read(favoritesProvider.notifier)
                                .toggleFavoriteStation(station);
                          },
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Play / Pause Action Button
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: IconButton.filled(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: isSelected && isPlaying
                                ? AppColors.accentCyan
                                : AppColors.surfaceHighlight,
                            foregroundColor: isSelected && isPlaying
                                ? AppColors.background
                                : Colors.white,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(38, 38),
                            maximumSize: const Size(40, 40),
                          ),
                          onPressed: onTogglePlay,
                          icon: isLoading && isSelected
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  isSelected && isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 22,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final label = isPlaying ? 'STREAMING' : 'READY';
    final color = isPlaying ? AppColors.accentEmerald : AppColors.accentCyan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Center(
      child: Icon(
        Icons.radio_rounded,
        color: isSelected ? Colors.white : AppColors.accentCyan,
        size: 26,
      ),
    );
  }
}
