import 'package:pulsecast/core/cache/cache_policy.dart';
import 'package:pulsecast/core/cache/cache_service.dart';
import 'package:pulsecast/core/network/api_client.dart';
import 'package:pulsecast/core/network/api_endpoints.dart';
import 'package:pulsecast/features/library/domain/models/listener_track.dart';
import 'package:pulsecast/features/stations/data/station_repository.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';

abstract class IListenerLibraryRepository {
  Future<List<ListenerTrack>> getLibraryTracks({int? stationId, String? search});
  Future<List<Station>> getAvailableStations();
}

class ListenerLibraryRepository implements IListenerLibraryRepository {
  final ApiClient _apiClient;
  final IStationRepository _stationRepository;
  final CacheService? _cacheService;

  ListenerLibraryRepository({
    required ApiClient apiClient,
    required IStationRepository stationRepository,
    CacheService? cacheService,
  })  : _apiClient = apiClient,
        _stationRepository = stationRepository,
        _cacheService = cacheService;

  @override
  Future<List<Station>> getAvailableStations() async {
    return _stationRepository.getStations();
  }

  @override
  Future<List<ListenerTrack>> getLibraryTracks({
    int? stationId,
    String? search,
  }) async {
    final stations = await _stationRepository.getStations();
    final targetStations = stationId != null
        ? stations.where((s) => s.id == stationId).toList()
        : stations.where((s) => !s.isLocalFallback).toList();

    final allTracks = <ListenerTrack>[];

    for (final station in targetStations) {
      try {
        final response = await _apiClient.get(ApiEndpoints.stationTracks(station.id));
        final data = response.data as Map<String, dynamic>;

        if (data['all_tracks'] != null && data['all_tracks'] is List) {
          final tracksJson = data['all_tracks'] as List;
          for (final item in tracksJson) {
            if (item is Map<String, dynamic>) {
              allTracks.add(
                ListenerTrack.fromJson(
                  item,
                  defaultStationId: station.id,
                  defaultStationName: station.name,
                ),
              );
            }
          }
        } else {
          // Fallback to now_playing + up_next if all_tracks is not present
          if (data['now_playing'] != null && data['now_playing'] is Map<String, dynamic>) {
            allTracks.add(
              ListenerTrack.fromJson(
                data['now_playing'] as Map<String, dynamic>,
                defaultStationId: station.id,
                defaultStationName: station.name,
              ),
            );
          }
          if (data['up_next'] != null && data['up_next'] is List) {
            for (final item in data['up_next'] as List) {
              if (item is Map<String, dynamic>) {
                allTracks.add(
                  ListenerTrack.fromJson(
                    item,
                    defaultStationId: station.id,
                    defaultStationName: station.name,
                  ),
                );
              }
            }
          }
        }
      } catch (_) {
        // Individual station track failure should not break entire library view
      }
    }

    // Cache tracks if unfiltered
    if (allTracks.isNotEmpty && stationId == null && (search == null || search.isEmpty)) {
      await _cacheService?.setJson(
        CachePolicy.keyListenerTracks,
        allTracks.map((t) => t.toJson()).toList(),
        ttl: CachePolicy.listenerTracksTtl,
      );
    } else if (allTracks.isEmpty && _cacheService != null) {
      // Offline fallback: load cached listener tracks
      final cached = _cacheService.getJson(
        CachePolicy.keyListenerTracks,
        allowExpired: true,
      );
      if (cached is List) {
        for (final item in cached) {
          if (item is Map<String, dynamic>) {
            final track = ListenerTrack.fromJson(item);
            if (stationId == null || track.stationId == stationId) {
              allTracks.add(track);
            }
          }
        }
      }
    }

    // Apply search filter if query is present
    if (search != null && search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      return allTracks.where((track) {
        final matchesTitle = track.title.toLowerCase().contains(query);
        final matchesArtist = track.artist.toLowerCase().contains(query);
        final matchesAlbum = track.album?.toLowerCase().contains(query) ?? false;
        final matchesStation = track.stationName.toLowerCase().contains(query);
        return matchesTitle || matchesArtist || matchesAlbum || matchesStation;
      }).toList();
    }

    return allTracks;
  }
}
