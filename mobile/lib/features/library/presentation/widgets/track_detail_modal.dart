import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/features/favorites/domain/models/favorite_song.dart';
import 'package:pulsecast/features/favorites/presentation/providers/favorites_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../stations/domain/models/station.dart';
import '../../../stations/presentation/providers/stations_provider.dart';
import '../../domain/models/listener_track.dart';

class TrackDetailModal extends ConsumerWidget {
  final ListenerTrack track;

  const TrackDetailModal({
    super.key,
    required this.track,
  });

  static Future<void> show(BuildContext context, ListenerTrack track) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TrackDetailModal(track: track),
    );
  }

  Future<void> _handleTuneIn(BuildContext context, WidgetRef ref) async {
    try {
      // 1. Check existing stations in cache
      final stationsAsync = ref.read(stationsListProvider);
      Station? targetStation;

      stationsAsync.whenData((stations) {
        try {
          targetStation = stations.firstWhere((s) => s.id == track.stationId);
        } catch (_) {}
      });

      // 2. Fallback to repository fetch if not found in cache
      if (targetStation == null) {
        final repo = ref.read(stationRepositoryProvider);
        targetStation = await repo.getStationById(track.stationId);
      }

      if (targetStation != null && context.mounted) {
        await ref
            .read(playerNotifierProvider.notifier)
            .playStation(targetStation!);
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tuned in to ${targetStation!.name}'),
              backgroundColor: AppColors.surfaceElevated,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not tune into station.'),
              backgroundColor: AppColors.accentCoral,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing station: $e'),
            backgroundColor: AppColors.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = track.isCurrentlyPlaying;
    final activeStation = ref.watch(currentStationProvider);
    final isTunedIn = activeStation?.id == track.stationId;
    final isFavorited = ref.watch(isSongFavoriteProvider('general_${track.id}'));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLarge),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingLarge,
        AppDimensions.paddingSmall,
        AppDimensions.paddingLarge,
        AppDimensions.paddingLarge + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Track Header with Icon
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
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
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(
                    color: isPlaying
                        ? AppColors.primary
                        : AppColors.borderSubtle,
                  ),
                ),
                child: Icon(
                  isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                  color: isPlaying ? AppColors.primary : AppColors.textSecondary,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppDimensions.paddingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artist,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (track.album != null && track.album!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        track.album!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFavorited ? AppColors.accentCoral : AppColors.textSecondary,
                  size: 26,
                ),
                tooltip: isFavorited ? 'Remove Favorite' : 'Save Track to Favorites',
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggleFavoriteSong(
                        FavoriteSong.fromListenerTrack(track),
                      );
                },
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingLarge),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: AppDimensions.paddingMedium),

          // Track Details Grid
          _buildInfoRow(
            icon: Icons.cell_tower_rounded,
            label: 'Broadcast Station',
            value: track.stationName,
            color: AppColors.accentCyan,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.access_time_rounded,
            label: 'Track Duration',
            value: track.duration ?? 'Live stream duration variable',
            color: AppColors.accentAmber,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: isPlaying ? Icons.radio_button_checked : Icons.queue_music_rounded,
            label: 'Playback Status',
            value: isPlaying
                ? 'Currently Playing LIVE'
                : 'Upcoming in Station Queue (Slot #${track.playOrder})',
            color: isPlaying ? AppColors.primary : AppColors.textSecondary,
          ),

          const SizedBox(height: AppDimensions.paddingLarge),

          // Tune In Action Button
          ElevatedButton.icon(
            onPressed: isTunedIn ? null : () => _handleTuneIn(context, ref),
            icon: Icon(
              isTunedIn ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(
              isTunedIn
                  ? 'Currently Listening to Station'
                  : 'Tune In to ${track.stationName}',
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppColors.surfaceElevated,
              disabledForegroundColor: AppColors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
