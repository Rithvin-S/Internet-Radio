import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/features/favorites/domain/models/favorite_song.dart';
import 'package:pulsecast/features/favorites/presentation/providers/favorites_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/listener_track.dart';

class ListenerTrackCard extends ConsumerWidget {
  final ListenerTrack track;
  final VoidCallback? onTap;
  final VoidCallback? onPlayStation;

  const ListenerTrackCard({
    super.key,
    required this.track,
    this.onTap,
    this.onPlayStation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = track.isCurrentlyPlaying;
    final isFavorited = ref.watch(isSongFavoriteProvider('general_${track.id}'));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: isPlaying
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.borderSubtle,
              width: isPlaying ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Track Icon / Leading
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPlaying
                        ? [
                            AppColors.primary.withValues(alpha: 0.3),
                            AppColors.accentCyan.withValues(alpha: 0.3),
                          ]
                        : [
                            AppColors.surfaceElevated,
                            AppColors.cardSurface,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  border: Border.all(
                    color: isPlaying
                        ? AppColors.primary.withValues(alpha: 0.6)
                        : AppColors.borderSubtle,
                  ),
                ),
                child: Icon(
                  isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                  color: isPlaying ? AppColors.primary : AppColors.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimensions.paddingMedium),

              // Title, Artist, Album, Station Tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            track.title,
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isPlaying
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPlaying) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.6),
                              ),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.album != null && track.album!.isNotEmpty
                          ? '${track.artist} • ${track.album}'
                          : track.artist,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Station Pill
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Text(
                              track.stationName,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (track.duration != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            track.duration!,
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

              // Favorite Heart Button
              IconButton(
                icon: Icon(
                  isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFavorited ? AppColors.accentCoral : AppColors.textMuted,
                  size: 20,
                ),
                tooltip: isFavorited ? 'Remove Favorite' : 'Save Track to Favorites',
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggleFavoriteSong(
                        FavoriteSong.fromListenerTrack(track),
                      );
                },
              ),

              // Details indicator
              IconButton(
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                onPressed: onTap,
                tooltip: 'Track Details',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
