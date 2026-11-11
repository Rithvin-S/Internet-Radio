import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/features/favorites/presentation/providers/favorites_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/models/station.dart';

/// Exact Reference StationCard:
/// Dark rounded card, 48x48 rounded artwork, bold title, genre subtitle,
/// active state has vibrant green border + 3 equalizer bars + circular pause button,
/// inactive state has dark circular play button with green border.
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isSelected && isPlaying) ? AppColors.primary : AppColors.border,
          width: (isSelected && isPlaying) ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Station Artwork Thumbnail (48x48 with 8px radius)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: AppColors.surfaceElevated,
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
                const SizedBox(width: 12),

                // 2. Flexible Center Content (Name & Subtitle)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        station.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        station.genre ?? '24/7 Live Radio',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Trailing Controls: Equalizer bars + Circular Play/Pause Button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Equalizer bars when actively playing
                    if (isSelected && isPlaying) ...[
                      const _MiniEqualizerBars(),
                      const SizedBox(width: 10),
                    ],

                    // Favorite quick toggle button
                    InkWell(
                      onTap: () {
                        ref.read(favoritesProvider.notifier).toggleFavoriteStation(station);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorite ? AppColors.primary : AppColors.textMuted,
                          size: 19,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Play/Pause Circular Action Button matching reference
                    GestureDetector(
                      onTap: onTogglePlay,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: isLoading && isSelected
                            ? const Center(
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : Icon(
                                (isSelected && isPlaying)
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: AppColors.primary,
                                size: 19,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return const Center(
      child: Icon(
        Icons.radio_rounded,
        color: AppColors.primary,
        size: 22,
      ),
    );
  }
}

/// 3 small green animated equalizer bars for currently active card
class _MiniEqualizerBars extends StatefulWidget {
  const _MiniEqualizerBars();

  @override
  State<_MiniEqualizerBars> createState() => _MiniEqualizerBarsState();
}

class _MiniEqualizerBarsState extends State<_MiniEqualizerBars> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 2.5,
              height: 6 + 10 * val,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 2.5),
            Container(
              width: 2.5,
              height: 16 - 8 * val,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 2.5),
            Container(
              width: 2.5,
              height: 8 + 8 * val,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        );
      },
    );
  }
}
