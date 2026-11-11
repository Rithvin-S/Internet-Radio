import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/cache_policy.dart';
import '../../../../core/cache/cache_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../providers/stations_provider.dart';
import '../widgets/station_card.dart';

class StationsScreen extends ConsumerStatefulWidget {
  const StationsScreen({super.key});

  @override
  ConsumerState<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends ConsumerState<StationsScreen> {
  final _searchController = TextEditingController();

  static const List<String> _genres = [
    'All',
    'Rock',
    'Vaporwave',
    'Alternative',
    'Ambient',
    'Mixed',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStationsAsync = ref.watch(filteredStationsProvider);
    final currentStation = ref.watch(currentStationProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final isAudioLoading = ref.watch(isAudioLoadingProvider);
    final selectedGenre = ref.watch(selectedGenreProvider);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stations', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await ref
                  .read(cacheServiceProvider)
                  .remove(CachePolicy.keyStationsList);
              ref.invalidate(stationsListProvider);
            },
            tooltip: 'Refresh Stations',
          ),
        ],
      ),
      body: Column(
        children: [
          // Pinned Search and Genre Filter Header with solid background to prevent scroll-under bleed
          Container(
            color: AppColors.background,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search Input Field
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: AppDimensions.paddingSmall,
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    cursorColor: AppColors.primary,
                    onChanged: (val) {
                      ref
                          .read(stationSearchQueryProvider.notifier)
                          .setQuery(val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search stations or genres...',
                      hintStyle: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: AppColors.textMuted,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(stationSearchQueryProvider.notifier)
                                    .setQuery('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.cardSurface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingMedium,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        borderSide:
                            const BorderSide(color: AppColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        borderSide:
                            const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // Horizontal Genre Chips
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: _genres.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final genre = _genres[index];
                      final isAll = genre == 'All';
                      final isSelected = isAll
                          ? (selectedGenre == null || selectedGenre.isEmpty)
                          : selectedGenre == genre;

                      return ChoiceChip(
                        label: Text(genre),
                        selected: isSelected,
                        onSelected: (selected) {
                          ref.read(selectedGenreProvider.notifier).select(
                                (isAll || !selected) ? null : genre,
                              );
                        },
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.cardSurface,
                        labelStyle: AppTypography.caption.copyWith(
                          color: isSelected
                              ? AppColors.background
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.borderSubtle,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppDimensions.space8),
              ],
            ),
          ),

          // Stations List View with generous bottom padding for Mini-Player clearance
          Expanded(
            child: filteredStationsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.signal_wifi_connected_no_internet_4_rounded,
                        color: AppColors.accentCoral,
                        size: 48,
                      ),
                      const SizedBox(height: AppDimensions.space16),
                      Text(
                        'Unable to load stations',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        err.toString(),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.background,
                        ),
                        onPressed: () => ref.refresh(stationsListProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (stations) {
                if (stations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          color: AppColors.textMuted,
                          size: 48,
                        ),
                        const SizedBox(height: AppDimensions.space16),
                        Text(
                          'No stations found',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try adjusting your search query or genre filter',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.accentCyan,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    ref.invalidate(stationsListProvider);
                    await ref.read(stationsListProvider.future);
                  },
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      top: AppDimensions.space8,
                      // Bottom padding clears the MiniPlayerWidget + safe margins
                      bottom: AppDimensions.space32 +
                          AppDimensions.miniPlayerHeight,
                      left: horizontalPadding,
                      right: horizontalPadding,
                    ),
                    itemCount: stations.length,
                    itemBuilder: (context, index) {
                      final station = stations[index];
                      final isStationSelected =
                          currentStation?.id == station.id;

                      return StationCard(
                        station: station,
                        isSelected: isStationSelected,
                        isPlaying: isStationSelected && isPlaying,
                        isLoading: isStationSelected && isAudioLoading,
                        onSelect: () {
                          ref
                              .read(playerNotifierProvider.notifier)
                              .playStation(station);
                        },
                        onTogglePlay: () {
                          if (isStationSelected) {
                            ref
                                .read(playerNotifierProvider.notifier)
                                .togglePlayPause();
                          } else {
                            ref
                                .read(playerNotifierProvider.notifier)
                                .playStation(station);
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
