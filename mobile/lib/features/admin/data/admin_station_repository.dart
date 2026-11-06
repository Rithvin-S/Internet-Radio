import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../stations/domain/models/station.dart';

abstract class IAdminStationRepository {
  Future<List<Station>> getStations({bool all = true});
  Future<Station> createStation({
    required String name,
    String? description,
    String? genre,
    required String streamUrl,
    String? artworkUrl,
    bool isActive = true,
  });
  Future<Station> updateStation(
    int id, {
    String? name,
    String? description,
    String? genre,
    String? streamUrl,
    String? artworkUrl,
    bool? isActive,
  });
  Future<bool> toggleStationStatus(int id, {bool? isActive});
  Future<void> deleteStation(int id);
}

class AdminStationRepository implements IAdminStationRepository {
  final ApiClient _apiClient;

  AdminStationRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<Station>> getStations({bool all = true}) async {
    final response = await _apiClient.get(
      ApiEndpoints.stations,
      queryParameters: all ? {'all': 'true'} : null,
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => Station.fromJson(item))
          .toList();
    }
    return [];
  }

  @override
  Future<Station> createStation({
    required String name,
    String? description,
    String? genre,
    required String streamUrl,
    String? artworkUrl,
    bool isActive = true,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.adminStations,
      data: {
        'name': name,
        if (description != null) 'description': description,
        if (genre != null) 'genre': genre,
        'stream_url': streamUrl,
        if (artworkUrl != null) 'artwork_url': artworkUrl,
        'is_active': isActive,
      },
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return Station.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException(message: 'Failed to create station');
  }

  @override
  Future<Station> updateStation(
    int id, {
    String? name,
    String? description,
    String? genre,
    String? streamUrl,
    String? artworkUrl,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (genre != null) body['genre'] = genre;
    if (streamUrl != null) body['stream_url'] = streamUrl;
    if (artworkUrl != null) body['artwork_url'] = artworkUrl;
    if (isActive != null) body['is_active'] = isActive;

    final response = await _apiClient.put(
      ApiEndpoints.adminStationDetail(id),
      data: body,
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return Station.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException(message: 'Failed to update station');
  }

  @override
  Future<bool> toggleStationStatus(int id, {bool? isActive}) async {
    final body = isActive != null ? {'is_active': isActive} : null;
    final response = await _apiClient.patch(
      ApiEndpoints.adminStationStatus(id),
      data: body,
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> &&
        data['data'] is Map<String, dynamic> &&
        data['data']['is_active'] is bool) {
      return data['data']['is_active'] as bool;
    }
    return isActive ?? true;
  }

  @override
  Future<void> deleteStation(int id) async {
    await _apiClient.delete(ApiEndpoints.adminStationDetail(id));
  }
}
