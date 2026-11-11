import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/listener_track.dart';

/// Exact Reference Track Card matching Screen 8:
/// 46x46 rounded artwork thumbnail, bold white title, "Artist • Duration" subtitle,
/// circular play button with green border, and 3-dots menu.
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaying ? AppColors.primary : AppColors.border,
          width: isPlaying ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 1. Artwork Thumbnail (46x46 with 8px radius)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 46,
                    height: 46,
                    color: AppColors.surfaceElevated,
                    child: Center(
                      child: Icon(
                        isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                        color: isPlaying ? AppColors.primary : AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Track Title & "Artist • Duration" Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.duration != null && track.duration!.isNotEmpty
                            ? '${track.artist} • ${track.duration}'
                            : track.artist,
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

                // 3. Circular Play Button matching reference
                GestureDetector(
                  onTap: onPlayStation ?? onTap,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 4. 3 Vertical Dots Menu Icon matching reference
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: onTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
