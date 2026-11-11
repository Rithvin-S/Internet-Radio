import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_typography.dart';
import '../../routing/route_names.dart';
import '../auth/presentation/providers/auth_providers.dart';
import '../stations/presentation/providers/stations_provider.dart';
import 'presentation/providers/listener_library_providers.dart';
import 'presentation/widgets/listener_track_card.dart';
import 'presentation/widgets/track_detail_modal.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authNotifierProvider).isAdmin;
    final selectedStationId = ref.watch(stationFilterProvider);
    final selectedStatus = ref.watch(trackStatusFilterProvider);
    final stationsAsync = ref.watch(stationsListProvider);
    final tracksAsync = ref.watch(filteredListenerTracksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.home);
            }
          },
        ),
        title: const Text('Library', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () => context.push(RouteNames.adminSongUpload),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.black, size: 22),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh Library',
              onPressed: () => ref.invalidate(listenerTracksProvider),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input matching reference
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingLarge,
                vertical: AppDimensions.paddingSmall,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  ref.read(librarySearchQueryProvider.notifier).setQuery(val);
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search tracks...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(librarySearchQueryProvider.notifier)
                                .setQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMedium,
                    vertical: AppDimensions.paddingSmall,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),

            // Horizontal Filter Chips: Stations & Status
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingLarge,
                ),
                children: [
                  // Station Filter: All
                  _buildFilterChip(
                    label: 'All Stations',
                    isSelected: selectedStationId == null,
                    onTap: () => ref
                        .read(stationFilterProvider.notifier)
                        .selectStation(null),
                  ),
                  const SizedBox(width: 8),

                  // Station Filter: Dynamic Stations
                  ...stationsAsync.when(
                    data: (stations) => stations.map((station) {
                      final isSelected = selectedStationId == station.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(
                          label: station.name,
                          isSelected: isSelected,
                          onTap: () => ref
                              .read(stationFilterProvider.notifier)
                              .selectStation(isSelected ? null : station.id),
                        ),
                      );
                    }).toList(),
                    loading: () => [],
                    error: (_, __) => [],
                  ),

                  const VerticalDivider(
                    color: AppColors.borderSubtle,
                    indent: 8,
                    endIndent: 8,
                    width: 16,
                  ),

                  // Status Filters: All / Playing / Queued
                  _buildFilterChip(
                    label: 'All Tracks',
                    isSelected: selectedStatus == 'All',
                    onTap: () => ref
                        .read(trackStatusFilterProvider.notifier)
                        .setFilter('All'),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Playing Now',
                    isSelected: selectedStatus == 'Playing',
                    accentColor: AppColors.primary,
                    onTap: () => ref
                        .read(trackStatusFilterProvider.notifier)
                        .setFilter('Playing'),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Queued',
                    isSelected: selectedStatus == 'Queued',
                    onTap: () => ref
                        .read(trackStatusFilterProvider.notifier)
                        .setFilter('Queued'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Track List
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () async {
                  ref.invalidate(listenerTracksProvider);
                  await ref.read(listenerTracksProvider.future);
                },
                child: tracksAsync.when(
                  data: (tracks) {
                    if (tracks.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.music_off_rounded,
                                    size: 56,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No tracks found',
                                    style: AppTypography.titleMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Try adjusting your search or station filters.',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.paddingLarge,
                        AppDimensions.paddingSmall,
                        AppDimensions.paddingLarge,
                        AppDimensions.paddingLarge,
                      ),
                      itemCount: tracks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppDimensions.paddingMedium),
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        return ListenerTrackCard(
                          track: track,
                          onTap: () => TrackDetailModal.show(context, track),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading broadcast music library...',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  error: (error, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: AppColors.accentCoral,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load tracks',
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Text(
                                  error.toString(),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    ref.invalidate(listenerTracksProvider),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final effectiveColor = accentColor ?? AppColors.primary;

    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: isSelected
          ? effectiveColor.withValues(alpha: 0.2)
          : AppColors.cardSurface,
      labelStyle: TextStyle(
        color: isSelected ? effectiveColor : AppColors.textSecondary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? effectiveColor : AppColors.borderSubtle,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }
}
