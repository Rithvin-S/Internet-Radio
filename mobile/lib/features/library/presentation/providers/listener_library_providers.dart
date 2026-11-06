import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/core/cache/cache_providers.dart';
import 'package:pulsecast/core/network/network_providers.dart';
import 'package:pulsecast/features/library/data/listener_library_repository.dart';
import 'package:pulsecast/features/library/domain/models/listener_track.dart';
import 'package:pulsecast/features/stations/presentation/providers/stations_provider.dart';

final listenerLibraryRepositoryProvider = Provider<IListenerLibraryRepository>((ref) {
  return ListenerLibraryRepository(
    apiClient: ref.watch(apiClientProvider),
    stationRepository: ref.watch(stationRepositoryProvider),
    cacheService: ref.watch(cacheServiceProvider),
  );
});

class StationFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null; // null = All Stations

  void selectStation(int? stationId) => state = stationId;
}

final stationFilterProvider =
    NotifierProvider<StationFilterNotifier, int?>(StationFilterNotifier.new);

class TrackStatusFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setFilter(String status) => state = status;
}

final trackStatusFilterProvider =
    NotifierProvider<TrackStatusFilterNotifier, String>(TrackStatusFilterNotifier.new);

class LibrarySearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final librarySearchQueryProvider =
    NotifierProvider<LibrarySearchNotifier, String>(LibrarySearchNotifier.new);

/// Fetches all accessible listener tracks from the active stations
final listenerTracksProvider = FutureProvider<List<ListenerTrack>>((ref) async {
  final repository = ref.watch(listenerLibraryRepositoryProvider);
  final stationId = ref.watch(stationFilterProvider);
  return repository.getLibraryTracks(stationId: stationId);
});

/// Combined filtered tracks based on search query, station filter, and status filter
final filteredListenerTracksProvider = Provider<AsyncValue<List<ListenerTrack>>>((ref) {
  final tracksAsync = ref.watch(listenerTracksProvider);
  final query = ref.watch(librarySearchQueryProvider).trim().toLowerCase();
  final status = ref.watch(trackStatusFilterProvider);

  return tracksAsync.whenData((tracks) {
    return tracks.where((track) {
      // 1. Status Filter
      if (status == 'Playing' && !track.isCurrentlyPlaying) return false;
      if (status == 'Queued' && !track.isQueued) return false;

      // 2. Search Query Filter
      if (query.isNotEmpty) {
        final matchesTitle = track.title.toLowerCase().contains(query);
        final matchesArtist = track.artist.toLowerCase().contains(query);
        final matchesAlbum = track.album?.toLowerCase().contains(query) ?? false;
        final matchesStation = track.stationName.toLowerCase().contains(query);
        if (!matchesTitle && !matchesArtist && !matchesAlbum && !matchesStation) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});
