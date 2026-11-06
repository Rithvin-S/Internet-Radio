import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/core/constants/app_colors.dart';
import 'package:pulsecast/core/constants/app_dimensions.dart';
import 'package:pulsecast/core/theme/app_typography.dart';
import 'package:pulsecast/features/player/presentation/providers/player_providers.dart';
import 'package:pulsecast/features/player/presentation/screens/full_player_screen.dart';

/// Persistent Mini Player widget anchored directly above bottom navigation
class MiniPlayerWidget extends ConsumerWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerNotifierProvider);
    final station = playerState.currentStation;
    final nowPlaying = playerState.nowPlaying;
    final isPlaying = playerState.isPlaying;
    final isLoading = playerState.isLoading;
    final isReconnecting = playerState.isReconnecting;

    // Hide mini player completely if no station has been loaded or selected
    if (station == null) {
      return const SizedBox.shrink();
    }

    final hasArtwork = station.artworkUrl != null &&
        station.artworkUrl!.startsWith('http');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => FullPlayerScreen.show(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMedium,
              vertical: 8,
            ),
            child: Row(
              children: [
                // Mini Artwork
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: isPlaying
                          ? AppColors.auroraGradient
                          : const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
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

                // Station & Live Status Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPlaying
                                  ? AppColors.connected
                                  : AppColors.buffering,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              station.name,
                              style: AppTypography.titleSmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nowPlaying?.displayTitle ??
                            (isReconnecting
                                ? 'Reconnecting...'
                                : (station.genre ?? 'Live Radio')),
                        style: AppTypography.caption.copyWith(
                          color: isReconnecting
                              ? AppColors.buffering
                              : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Play / Pause Button
                IconButton(
                  icon: (isLoading || isReconnecting)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentCyan,
                          ),
                        )
                      : Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 30,
                          color: AppColors.accentCyan,
                        ),
                  onPressed: () {
                    ref.read(playerNotifierProvider.notifier).togglePlayPause();
                  },
                ),

                // Stop / Dismiss Button
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () {
                    ref.read(playerNotifierProvider.notifier).stop();
                  },
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
        color: Colors.white,
        size: 24,
      ),
    );
  }
}
