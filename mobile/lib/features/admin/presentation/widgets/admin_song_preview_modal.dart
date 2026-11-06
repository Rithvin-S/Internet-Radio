import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:pulsecast/features/admin/domain/models/admin_song.dart';
import '../providers/admin_providers.dart';

class AdminSongPreviewModal extends ConsumerStatefulWidget {
  final AdminSong song;

  const AdminSongPreviewModal({super.key, required this.song});

  static Future<void> show(BuildContext context, AdminSong song) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdminSongPreviewModal(song: song),
    );
  }

  @override
  ConsumerState<AdminSongPreviewModal> createState() =>
      _AdminSongPreviewModalState();
}

class _AdminSongPreviewModalState extends ConsumerState<AdminSongPreviewModal> {
  AudioPlayer? _player;
  bool _isLoading = true;
  String? _errorMessage;
  int _remainingSeconds = 300;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _fetchSignedUrlAndPlay();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _player?.stop();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _fetchSignedUrlAndPlay() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminSongRepositoryProvider);
      final signedUrlInfo = await repo.getSignedUrl(widget.song.id);
      _remainingSeconds = signedUrlInfo.expiresIn;

      // Start countdown timer for ephemeral signed URL
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          timer.cancel();
          setState(() {
            _errorMessage = 'Signed URL expired. Reopen modal to regenerate.';
          });
          _player?.stop();
        }
      });

      // Initialize player
      _player = AudioPlayer();
      await _player!.setUrl(signedUrlInfo.signedUrl);
      _player!.play();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
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

          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accentViolet.withValues(alpha: 0.2),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: const Icon(
                  Icons.headphones_rounded,
                  color: AppColors.accentViolet,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.song.artist,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Expiry badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: AppColors.accentAmber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_remainingSeconds}s',
                      style: const TextStyle(
                        color: AppColors.accentAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingLarge),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 12),
                    Text(
                      'Requesting short-lived signed URL...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.accentCoral.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(
                  color: AppColors.accentCoral.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.accentCoral,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _fetchSignedUrlAndPlay,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            )
          else if (_player != null)
            StreamBuilder<PlayerState>(
              stream: _player!.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final isPlaying = playerState?.playing ?? false;

                return Column(
                  children: [
                    // Position slider
                    StreamBuilder<Duration>(
                      stream: _player!.positionStream,
                      builder: (context, posSnap) {
                        final pos = posSnap.data ?? Duration.zero;
                        final duration = _player!.duration ?? Duration.zero;
                        final maxVal = duration.inMilliseconds.toDouble();
                        final curVal = pos.inMilliseconds
                            .toDouble()
                            .clamp(0.0, maxVal > 0 ? maxVal : 1.0);

                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: AppColors.surfaceHighlight,
                                thumbColor: AppColors.primary,
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                              ),
                              child: Slider(
                                value: curVal,
                                max: maxVal > 0 ? maxVal : 1.0,
                                onChanged: (val) {
                                  _player!.seek(
                                    Duration(milliseconds: val.toInt()),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(pos),
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Playback Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 44,
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            if (isPlaying) {
                              _player!.pause();
                            } else {
                              _player!.play();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.stop_rounded,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            _player!.stop();
                            _player!.seek(Duration.zero);
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
