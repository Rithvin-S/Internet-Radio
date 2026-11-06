import 'package:pulsecast/core/cache/cache_policy.dart';
import 'package:pulsecast/core/cache/cache_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/models/station.dart';

abstract class IStationRepository {
  Future<List<Station>> getStations({
    bool all = false,
    String? genre,
    String? search,
  });

  Future<Station> getStationById(int id);
}

class StationRepository implements IStationRepository {
  final ApiClient _apiClient;
  final CacheService? _cacheService;

  StationRepository({
    required ApiClient apiClient,
    CacheService? cacheService,
  })  : _apiClient = apiClient,
        _cacheService = cacheService;

  @override
  Future<List<Station>> getStations({
    bool all = false,
    String? genre,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{};
    if (all) queryParams['all'] = 'true';
    if (genre != null && genre.isNotEmpty) queryParams['genre'] = genre;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final isBaseQuery = !all && (genre == null || genre.isEmpty) && (search == null || search.isEmpty);

    // Fast cache-first path: return valid cached stations immediately without network stall
    if (isBaseQuery && _cacheService != null) {
      final cached = _cacheService.getJson(
        CachePolicy.keyStationsList,
        allowExpired: false,
      );
      if (cached is List && cached.isNotEmpty) {
        final list = cached
            .whereType<Map<String, dynamic>>()
            .map((item) => Station.fromJson(item))
            .toList();

        if (list.isNotEmpty) {
          // Asynchronously revalidate in background to keep cached catalog fresh
          _revalidateStationsInBackground();
          return list;
        }
      }
    }

    try {
      final response = await _apiClient.get(
        ApiEndpoints.stations,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        final list = (data['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => Station.fromJson(item))
            .toList();

        // Cache base station list when unfiltered
        if (isBaseQuery) {
          await _cacheService?.setJson(
            CachePolicy.keyStationsList,
            data['data'],
            ttl: CachePolicy.stationsTtl,
          );
        }

        return list;
      }
      return [];
    } catch (e) {
      // Offline fallback: attempt retrieval from local cache
      if (_cacheService != null) {
        final cached = _cacheService.getJson(
          CachePolicy.keyStationsList,
          allowExpired: true,
        );
        if (cached is List) {
          var list = cached
              .whereType<Map<String, dynamic>>()
              .map((item) => Station.fromJson(item))
              .toList();

          if (genre != null && genre.isNotEmpty) {
            list = list
                .where((s) => s.genre != null && s.genre!.contains(genre))
                .toList();
          }

          if (search != null && search.isNotEmpty) {
            final query = search.toLowerCase();
            list = list
                .where((s) =>
                    s.name.toLowerCase().contains(query) ||
                    (s.description != null &&
                        s.description!.toLowerCase().contains(query)))
                .toList();
          }

          return list;
        }
      }
      rethrow;
    }
  }

  @override
  Future<Station> getStationById(int id) async {
    final cacheKey = '${CachePolicy.keyStationPrefix}$id';

    try {
      final response = await _apiClient.get('${ApiEndpoints.stations}/$id');
      final data = response.data;

      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
        final station = Station.fromJson(data['data'] as Map<String, dynamic>);
        await _cacheService?.setJson(
          cacheKey,
          data['data'],
          ttl: CachePolicy.stationDetailTtl,
        );
        return station;
      }

      throw Exception('Failed to load station details for ID #$id');
    } catch (e) {
      // Offline fallback
      if (_cacheService != null) {
        final cached = _cacheService.getJson(cacheKey, allowExpired: true);
        if (cached is Map<String, dynamic>) {
          return Station.fromJson(cached);
        }

        // Try to find in full stations cache
        final allCached = _cacheService.getJson(
          CachePolicy.keyStationsList,
          allowExpired: true,
        );
        if (allCached is List) {
          final found = allCached
              .whereType<Map<String, dynamic>>()
              .map((item) => Station.fromJson(item))
              .where((s) => s.id == id);
          if (found.isNotEmpty) return found.first;
        }
      }
      rethrow;
    }
  }

  void _revalidateStationsInBackground() {
    _apiClient.get(ApiEndpoints.stations).then((response) {
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        _cacheService?.setJson(
          CachePolicy.keyStationsList,
          data['data'],
          ttl: CachePolicy.stationsTtl,
        );
      }
    }).catchError((_) => null);
  }
}
