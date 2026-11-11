import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/connectivity/connectivity_providers.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../routing/route_names.dart';
import '../../../favorites/domain/models/favorite_song.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';
import '../../../player/domain/models/channel6_now_playing.dart';
import '../../../player/presentation/providers/channel6_now_playing_provider.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../player/presentation/providers/player_state.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../stations/domain/models/station.dart';
import '../../../stations/presentation/providers/stations_provider.dart';

/// PulseCast Exact Reference UI: Dedicated Radio Now-Playing Screen
class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});

  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen>
    with WidgetsBindingObserver {
  static const Station _defaultChannel6Station = Station(
    id: 6,
    name: 'PulseCast Radio',
    description: 'Automated 24/7 Continuous Radio',
    genre: 'Mixed / Electronic',
    streamUrl: AppConfig.channel6StreamUrl,
    isActive: true,
  );

  bool _hasCheckedAutoplay = false;
  double _volume = 1.0;
  bool _isShuffle = false;
  bool _isRepeat = false;

  Station _resolveDefaultChannel6(List<Station>? stations) {
    if (stations != null) {
      for (final s in stations) {
        if (s.isChannel6) return s;
      }
    }
    return _defaultChannel6Station;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _volume = ref.read(playerNotifierProvider.notifier).volume;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAutoplay();
      _syncChannel6Selection();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (!mounted) return;
    final notifier = ref.read(channel6NowPlayingProvider.notifier);
    if (appState == AppLifecycleState.resumed) {
      notifier.setAppForeground(true);
    } else if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.detached) {
      notifier.setAppForeground(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _syncChannel6Selection() {
    if (!mounted) return;
    final stations = ref.read(stationsListProvider).asData?.value;
    final current = ref.read(playerNotifierProvider).currentStation;
    final activeStation = current ?? _resolveDefaultChannel6(stations);
    final notifier = ref.read(channel6NowPlayingProvider.notifier);

    if (activeStation.isChannel6) {
      notifier.activateForChannel6(streamUrl: activeStation.effectiveStreamUrl);
    } else {
      notifier.deactivate();
    }
  }

  void _handleAutoplay() {
    if (!mounted || _hasCheckedAutoplay) return;
    _hasCheckedAutoplay = true;

    final playerState = ref.read(playerNotifierProvider);
    final settings = ref.read(userSettingsProvider);
    final isOnline = ref.read(isOnlineProvider);

    if (settings.autoplayOnLaunch &&
        isOnline &&
        playerState.status == RadioPlaybackStatus.idle &&
        !playerState.isPlaying &&
        !playerState.isLoading) {
      final stations = ref.read(stationsListProvider).asData?.value;
      final target =
          playerState.currentStation ?? _resolveDefaultChannel6(stations);
      ref.read(playerNotifierProvider.notifier).playStation(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerNotifierProvider);
    final stationsAsync = ref.watch(stationsListProvider);
    final channel6State = ref.watch(channel6NowPlayingProvider);

    ref.listen<Station?>(
      playerNotifierProvider.select((s) => s.currentStation),
      (previous, next) {
        if (next == null) {
          Future.microtask(_syncChannel6Selection);
        }
      },
    );

    ref.listen<AsyncValue<List<Station>>>(stationsListProvider, (prev, next) {
      final current = ref.read(playerNotifierProvider).currentStation;
      if (current == null) {
        final resolved = _resolveDefaultChannel6(next.asData?.value);
        Future.microtask(() {
          if (!mounted) return;
          ref
              .read(channel6NowPlayingProvider.notifier)
              .activateForChannel6(streamUrl: resolved.effectiveStreamUrl);
        });
      }
    });

    final station = playerState.currentStation ??
        _resolveDefaultChannel6(stationsAsync.asData?.value);
    final isChannel6 = station.isChannel6;
    final displayStationName = isChannel6 ? 'PulseCast Radio' : station.name;
    final nowPlaying = playerState.nowPlaying;
    final isPlaying = playerState.isPlaying;
    final isLoading = playerState.isLoading;
    final isReconnecting = playerState.isReconnecting;
    final hasError = playerState.hasError;

    final modalNowPlayingText = isChannel6
        ? (channel6State.track != null
            ? '${channel6State.track!.title} — ${channel6State.track!.artist}'
            : 'PulseCast Radio Live Stream')
        : (nowPlaying?.displayTitle ??
            (station.description ?? 'Continuous 24/7 Broadcast'));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const _PulseCastHeaderLogo(),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 23),
            tooltip: 'Broadcast Info',
            onPressed: () {
              final isFav = ref.read(isStationFavoriteProvider(station.id));
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (sheetContext) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cell_tower_rounded, color: AppColors.primary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                displayStationName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isPlaying ? 'LIVE' : 'STANDBY',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Now Playing: $modalNowPlayingText',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  ref.read(favoritesProvider.notifier).toggleFavoriteStation(station);
                                  Navigator.pop(sheetContext);
                                },
                                icon: Icon(
                                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                label: Text(isFav ? 'Remove Favourite' : 'Save Station'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  context.push(RouteNames.stations);
                                },
                                icon: const Icon(Icons.radio_rounded, size: 18),
                                label: const Text('All Stations'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 22),
            tooltip: 'Settings',
            onPressed: () => context.push(RouteNames.settings),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isChannel6) ...[
                const SizedBox(height: 8),

                // Station name for Channel 6
                Text(
                  displayStationName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Song information positioned between station name and vinyl artwork
                _Channel6NowPlayingBanner(
                  nowPlayingState: channel6State,
                  isPlaying: isPlaying,
                ),

                const SizedBox(height: 20),

                // Central Glowing Vinyl Record Disc
                _VinylRecordDisc(
                  artworkUrl: station.artworkUrl,
                  isPlaying: isPlaying,
                  stationName: displayStationName,
                ),

                const SizedBox(height: 20),
              ] else ...[
                const SizedBox(height: 12),

                // 1. Exact Reference Central Glowing Vinyl Record Disc
                _VinylRecordDisc(
                  artworkUrl: station.artworkUrl,
                  isPlaying: isPlaying,
                  stationName: station.name,
                ),

                const SizedBox(height: 28),

                // 2. Station Title & Subtitle
                Text(
                  station.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nowPlaying?.displayTitle ?? (station.genre ?? 'Live Radio'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 10),
              ],

              // 3. Exact Reference LIVE Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPlaying ? AppColors.primary : AppColors.textMuted,
                      boxShadow: isPlaying
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.6),
                                blurRadius: 6,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: isPlaying ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 4. Exact Reference Green Audio Waveform Visualizer
              _WaveformVisualizer(isPlaying: isPlaying),

              const SizedBox(height: 28),

              // Error banner if any
              if (hasError && playerState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentCoral.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentCoral.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.accentCoral, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          playerState.errorMessage!,
                          style: const TextStyle(color: AppColors.accentCoral, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.read(playerNotifierProvider.notifier).playStation(station),
                        child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Exact Reference Playback Controls Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Shuffle Button
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: _isShuffle ? AppColors.primary : AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _isShuffle = !_isShuffle),
                  ),

                  // Previous Station
                  IconButton(
                    icon: const Icon(
                      Icons.skip_previous_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () => _switchStation(ref, station, isNext: false),
                  ),

                  // Primary Solid Green Play / Pause Button
                  GestureDetector(
                    onTap: (isLoading || isReconnecting)
                        ? null
                        : () {
                            final notifier = ref.read(playerNotifierProvider.notifier);
                            if (playerState.currentStation == null || playerState.isIdle) {
                              notifier.playStation(station);
                            } else {
                              notifier.togglePlayPause();
                            }
                          },
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: (isLoading || isReconnecting)
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 36,
                              color: Colors.white,
                            ),
                    ),
                  ),

                  // Next Station
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () => _switchStation(ref, station, isNext: true),
                  ),

                  // Repeat Button
                  IconButton(
                    icon: Icon(
                      Icons.repeat_rounded,
                      color: _isRepeat ? AppColors.primary : AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _isRepeat = !_isRepeat),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 6. Exact Reference Volume Slider Row
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded, size: 18, color: AppColors.textSecondary),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.surfaceHighlight,
                        trackHeight: 3,
                        thumbColor: AppColors.primary,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      ),
                      child: Slider(
                        value: _volume,
                        onChanged: (val) {
                          setState(() => _volume = val);
                          ref.read(playerNotifierProvider.notifier).setVolume(val);
                        },
                      ),
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, size: 18, color: AppColors.textSecondary),
                ],
              ),

              const SizedBox(height: 24),

              // 7. Quick Station Switcher (Compact carousel at bottom of scrollable area)
              _buildBottomStationDrawer(context, ref, stationsAsync, station.id),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomStationDrawer(
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
              'Other Stations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            TextButton(
              onPressed: () => context.push(RouteNames.stations),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
              ),
              child: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        stationsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (stations) {
            final activeStations = stations.where((s) => s.isActive).toList();
            if (activeStations.isEmpty) return const SizedBox.shrink();

            return SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: activeStations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final s = activeStations[index];
                  final isSelected = s.id == currentStationId;

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (!isSelected) {
                        ref.read(playerNotifierProvider.notifier).playStation(s);
                      }
                    },
                    child: Container(
                      width: 170,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 36,
                              height: 36,
                              color: AppColors.surfaceElevated,
                              child: (s.artworkUrl != null && s.artworkUrl!.startsWith('http'))
                                  ? CachedNetworkImage(
                                      imageUrl: s.artworkUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => const Icon(
                                        Icons.radio_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.radio_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? AppColors.primary : Colors.white,
                                  ),
                                ),
                                Text(
                                  s.genre ?? 'Live Radio',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
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
}

/// Header Logo matching the reference: Electric green pulse waveform + white "PulseCast"
class _PulseCastHeaderLogo extends StatelessWidget {
  const _PulseCastHeaderLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(26, 20),
          painter: _PulseWaveformPainter(color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        const Text(
          'PulseCast',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _PulseWaveformPainter extends CustomPainter {
  final Color color;
  const _PulseWaveformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final h = size.height;
    final w = size.width;

    path.moveTo(0, h * 0.5);
    path.lineTo(w * 0.18, h * 0.5);
    path.lineTo(w * 0.32, h * 0.22);
    path.lineTo(w * 0.48, h * 0.82);
    path.lineTo(w * 0.64, h * 0.1);
    path.lineTo(w * 0.78, h * 0.68);
    path.lineTo(w * 0.88, h * 0.5);
    path.lineTo(w, h * 0.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PulseWaveformPainter oldDelegate) => oldDelegate.color != color;
}

/// Exact Reference Visualizer: Green audio waveform bars right under LIVE tag
class _WaveformVisualizer extends StatefulWidget {
  final bool isPlaying;

  const _WaveformVisualizer({required this.isPlaying});

  @override
  State<_WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<_WaveformVisualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  static const List<double> _baseHeights = [
    6, 10, 16, 22, 14, 18, 24, 12, 8, 18, 26, 20, 14, 22, 28, 16, 10, 20, 24, 18, 12, 8, 14, 8, 6
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _animController.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final animValue = _animController.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_baseHeights.length, (i) {
            final base = _baseHeights[i];
            final factor = widget.isPlaying
                ? (0.4 + 0.6 * ((i % 3 == 0) ? animValue : (1.0 - animValue)))
                : 0.35;
            final height = (base * factor).clamp(4.0, 26.0);
            return Container(
              width: 3.2,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.6),
              decoration: BoxDecoration(
                color: widget.isPlaying ? AppColors.primary : AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Exact Reference Vinyl Record Disc:
/// Circular disc with soft green radiant glow, neon green rim border,
/// realistic concentric grooves, specular rainbow/metallic reflections, and center hub.
class _VinylRecordDisc extends StatefulWidget {
  final String? artworkUrl;
  final bool isPlaying;
  final String stationName;

  const _VinylRecordDisc({
    this.artworkUrl,
    required this.isPlaying,
    required this.stationName,
  });

  @override
  State<_VinylRecordDisc> createState() => _VinylRecordDiscState();
}

class _VinylRecordDiscState extends State<_VinylRecordDisc> with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _VinylRecordDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _rotationController.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width * 0.68;
    final boundedSize = size.clamp(210.0, 270.0);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Ambient Green Glow Halo behind the vinyl record
          Container(
            width: boundedSize + 20,
            height: boundedSize + 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.isPlaying
                      ? AppColors.primary.withValues(alpha: 0.38)
                      : AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 46,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),

          // 2. Rotating Vinyl Disc Body
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: boundedSize,
              height: boundedSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary,
                  width: 1.8,
                ),
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF0A0C0E),
                    Color(0xFF14181E),
                    Color(0xFF08090B),
                    Color(0xFF1C222A),
                    Color(0xFF090A0D),
                  ],
                  stops: [0.0, 0.45, 0.7, 0.9, 1.0],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Concentric micro-grooves
                  CustomPaint(
                    size: Size(boundedSize, boundedSize),
                    painter: _VinylGroovesPainter(),
                  ),

                  // Metallic specular reflection sheen
                  Container(
                    width: boundedSize,
                    height: boundedSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0x334ADE80), // Soft green sheen
                          Colors.transparent,
                          const Color(0x28A855F7), // Soft purple sheen
                          Colors.transparent,
                          const Color(0x3338BDF8), // Soft cyan sheen
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.15, 0.35, 0.55, 0.7, 0.85, 1.0],
                      ),
                    ),
                  ),

                  // Center circular hub label
                  Container(
                    width: boundedSize * 0.34,
                    height: boundedSize * 0.34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF16191E),
                      border: Border.all(color: AppColors.borderLight, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 10),
                      ],
                    ),
                    child: ClipOval(
                      child: (widget.artworkUrl != null && widget.artworkUrl!.startsWith('http'))
                          ? CachedNetworkImage(
                              imageUrl: widget.artworkUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _buildHubFallback(),
                            )
                          : _buildHubFallback(),
                    ),
                  ),

                  // Center spindle hole
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background,
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHubFallback() {
    return Container(
      color: const Color(0xFF1A1F26),
      child: const Center(
        child: Icon(Icons.music_note_rounded, size: 24, color: AppColors.primary),
      ),
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 8;

    for (double r = 45; r < maxRadius; r += 7) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VinylGroovesPainter oldDelegate) => false;
}

/// Displays Channel 6 live track metadata (title + artist) positioned between
/// the station name and vinyl artwork, with loading and error fallbacks.
class _Channel6NowPlayingBanner extends StatelessWidget {
  final Channel6NowPlayingState nowPlayingState;
  final bool isPlaying;

  const _Channel6NowPlayingBanner({
    required this.nowPlayingState,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final track = nowPlayingState.track;
    final isInitialLoading =
        nowPlayingState.isLoading && !nowPlayingState.hasLoadedOnce;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: track != null && isPlaying
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildBody(isInitialLoading, track),
      ),
    );
  }

  Widget _buildBody(bool isInitialLoading, Channel6NowPlayingTrack? track) {
    if (isInitialLoading && track == null) {
      return const Padding(
        key: ValueKey('ch6-loading'),
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Loading currently playing song...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (track != null) {
      return Column(
        key: ValueKey('ch6-track-${track.title}-${track.artist}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              SizedBox(width: 5),
              Text(
                'NOW PLAYING',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            track.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            track.artist,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Column(
      key: ValueKey('ch6-fallback-${nowPlayingState.hasError}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '24/7 Automated Stream',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          nowPlayingState.hasError
              ? 'Song info temporarily unavailable'
              : 'Continuous live broadcast',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
