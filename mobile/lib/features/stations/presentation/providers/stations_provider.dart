import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/cache/cache_providers.dart';
import '../../data/station_repository.dart';
import '../../domain/models/station.dart';

/// Provider for StationRepository
final stationRepositoryProvider = Provider<IStationRepository>((ref) {
  return StationRepository(
    apiClient: ref.watch(apiClientProvider),
    cacheService: ref.watch(cacheServiceProvider),
  );
});

/// Provider fetching all stations from the backend (cached in-memory for instant navigation)
final stationsListProvider = FutureProvider<List<Station>>((ref) async {
  final repository = ref.watch(stationRepositoryProvider);
  return await repository.getStations();
});

/// Notifier for station genre filter
class SelectedGenreNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? genre) {
    state = genre;
  }
}

final selectedGenreProvider =
    NotifierProvider<SelectedGenreNotifier, String?>(SelectedGenreNotifier.new);

/// Notifier for station search query
class StationSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final stationSearchQueryProvider =
    NotifierProvider<StationSearchQueryNotifier, String>(
  StationSearchQueryNotifier.new,
);

/// Computed provider for stations filtered by genre and search (cached for instant tab switching)
final filteredStationsProvider = Provider<AsyncValue<List<Station>>>((ref) {
  final stationsAsync = ref.watch(stationsListProvider);
  final selectedGenre = ref.watch(selectedGenreProvider);
  final searchQuery = ref.watch(stationSearchQueryProvider).trim().toLowerCase();

  return stationsAsync.whenData((stations) {
    return stations.where((station) {
      final matchesGenre = selectedGenre == null ||
          selectedGenre.isEmpty ||
          (station.genre != null && station.genre!.contains(selectedGenre));

      final matchesSearch = searchQuery.isEmpty ||
          station.name.toLowerCase().contains(searchQuery) ||
          (station.description != null &&
              station.description!.toLowerCase().contains(searchQuery));

      return matchesGenre && matchesSearch;
    }).toList();
  });
});
