import 'package:pulsecast/core/cache/cache_policy.dart';
import 'package:pulsecast/core/cache/cache_service.dart';
import 'package:pulsecast/core/network/api_client.dart';
import 'package:pulsecast/core/network/api_endpoints.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import '../domain/models/favorite_song.dart';

abstract class IFavoritesRepository {
  /// Fetches favorite stations from the server (if authenticated) and local cache
  Future<List<Station>> getFavoriteStations({String? userId, bool isOnline = true});

  /// Adds a station to favorites
  Future<bool> addFavoriteStation(Station station, {String? userId, bool isOnline = true});

  /// Removes a station from favorites
  Future<bool> removeFavoriteStation(int stationId, {String? userId, bool isOnline = true});

  /// Gets the set of favorite station IDs
  Set<int> getLocalFavoriteStationIds({String? userId});

  /// Fetches favorite songs (stored locally, strictly scoped by user)
  List<FavoriteSong> getFavoriteSongs({String? userId});

  /// Adds a song to favorites locally
  Future<void> addFavoriteSong(FavoriteSong song, {String? userId});

  /// Removes a song from favorites locally
  Future<void> removeFavoriteSong(String favoriteId, {String? userId});

  /// Merges guest favorites into the authenticated user's account
  Future<List<int>> mergeGuestFavorites({required String userId, bool isOnline = true});
}

class FavoritesRepository implements IFavoritesRepository {
  final ApiClient _apiClient;
  final CacheService _cacheService;

  FavoritesRepository({
    required ApiClient apiClient,
    required CacheService cacheService,
  })  : _apiClient = apiClient,
        _cacheService = cacheService;

  String _stationKey(String? userId) =>
      '${CachePolicy.keyFavoritesStationsPrefix}${userId ?? 'guest'}';

  String _songKey(String? userId) =>
      '${CachePolicy.keyFavoritesSongsPrefix}${userId ?? 'guest'}';

  @override
  Set<int> getLocalFavoriteStationIds({String? userId}) {
    final key = _stationKey(userId);
    var raw = _cacheService.getJson(key, allowExpired: true);

    // Legacy un-scoped key migration: if scoped key is empty, check legacy key
    if ((raw == null || (raw is List && raw.isEmpty)) &&
        _cacheService.has('pulsecast_fav_stations')) {
      final legacyRaw = _cacheService.getJson('pulsecast_fav_stations', allowExpired: true);
      if (legacyRaw is List && legacyRaw.isNotEmpty) {
        _cacheService.setJson(key, legacyRaw);
        _cacheService.remove('pulsecast_fav_stations');
        raw = legacyRaw;
      }
    }

    if (raw is List) {
      return raw.whereType<int>().toSet();
    }
    return {};
  }

  Future<void> _saveLocalFavoriteStationIds(Set<int> ids, {String? userId}) async {
    await _cacheService.setJson(_stationKey(userId), ids.toList());
  }

  @override
  Future<List<Station>> getFavoriteStations({
    String? userId,
    bool isOnline = true,
  }) async {
    final localIds = getLocalFavoriteStationIds(userId: userId);

    // If authenticated and online, fetch latest authoritative favorites from server
    if (userId != null && isOnline) {
      try {
        final response = await _apiClient.get(ApiEndpoints.favourites);
        final data = response.data;
        if (data is Map<String, dynamic> && data['data'] is List) {
          final serverStations = (data['data'] as List)
              .whereType<Map<String, dynamic>>()
              .map((item) => Station.fromJson(item))
              .toList();

          // Sync local ID cache with authoritative server state
          final serverIds = serverStations.map((s) => s.id).toSet();
          await _saveLocalFavoriteStationIds(serverIds, userId: userId);

          // Also cache these station records in cache service
          await _cacheService.setJson(
            '${_stationKey(userId)}_records',
            serverStations.map((s) => s.toJson()).toList(),
          );

          return serverStations;
        }
      } catch (_) {
        // Fall back to cached favorites below
      }
    }

    // Offline or guest: load cached station objects or match local IDs against cached stations
    final cachedRecordsRaw = _cacheService.getJson(
      '${_stationKey(userId)}_records',
      allowExpired: true,
    );
    if (cachedRecordsRaw is List && cachedRecordsRaw.isNotEmpty) {
      final cachedStations = cachedRecordsRaw
          .whereType<Map<String, dynamic>>()
          .map((item) => Station.fromJson(item))
          .where((s) => localIds.contains(s.id))
          .toList();
      if (cachedStations.isNotEmpty) return cachedStations;
    }

    // Secondary fallback: inspect main stations cache
    final allStationsRaw = _cacheService.getJson(
      CachePolicy.keyStationsList,
      allowExpired: true,
    );
    if (allStationsRaw is List) {
      return allStationsRaw
          .whereType<Map<String, dynamic>>()
          .map((item) => Station.fromJson(item))
          .where((s) => localIds.contains(s.id))
          .toList();
    }

    return [];
  }

  @override
  Future<bool> addFavoriteStation(
    Station station, {
    String? userId,
    bool isOnline = true,
  }) async {
    // 1. Immediately update local state
    final ids = getLocalFavoriteStationIds(userId: userId);
    ids.add(station.id);
    await _saveLocalFavoriteStationIds(ids, userId: userId);

    // Cache the station record
    final cachedStations = await getFavoriteStations(userId: userId, isOnline: false);
    if (!cachedStations.any((s) => s.id == station.id)) {
      cachedStations.add(station);
      await _cacheService.setJson(
        '${_stationKey(userId)}_records',
        cachedStations.map((s) => s.toJson()).toList(),
      );
    }

    // 2. Synchronize to server if authenticated and online
    if (userId != null && isOnline) {
      try {
        final response = await _apiClient.post(
          ApiEndpoints.favouriteStation(station.id),
        );
        return response.statusCode == 200 || response.statusCode == 201;
      } catch (_) {
        return false;
      }
    }

    return true;
  }

  @override
  Future<bool> removeFavoriteStation(
    int stationId, {
    String? userId,
    bool isOnline = true,
  }) async {
    // 1. Immediately remove from local state
    final ids = getLocalFavoriteStationIds(userId: userId);
    ids.remove(stationId);
    await _saveLocalFavoriteStationIds(ids, userId: userId);

    // Update cached records
    final cachedStations = await getFavoriteStations(userId: userId, isOnline: false);
    cachedStations.removeWhere((s) => s.id == stationId);
    await _cacheService.setJson(
      '${_stationKey(userId)}_records',
      cachedStations.map((s) => s.toJson()).toList(),
    );

    // 2. Synchronize removal to server if authenticated and online
    if (userId != null && isOnline) {
      try {
        final response = await _apiClient.delete(
          ApiEndpoints.favouriteStation(stationId),
        );
        return response.statusCode == 200;
      } catch (_) {
        return false;
      }
    }

    return true;
  }

  @override
  List<FavoriteSong> getFavoriteSongs({String? userId}) {
    final key = _songKey(userId);
    var raw = _cacheService.getJson(key, allowExpired: true);

    // Legacy un-scoped key migration: if scoped key is empty, check legacy global key
    if ((raw == null || (raw is List && raw.isEmpty)) &&
        _cacheService.has('pulsecast_fav_songs')) {
      final legacyRaw = _cacheService.getJson('pulsecast_fav_songs', allowExpired: true);
      if (legacyRaw is List && legacyRaw.isNotEmpty) {
        _cacheService.setJson(key, legacyRaw);
        _cacheService.remove('pulsecast_fav_songs');
        raw = legacyRaw;
      }
    }

    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((item) => FavoriteSong.fromJson(item))
          .toList();
    }
    return [];
  }

  @override
  Future<void> addFavoriteSong(FavoriteSong song, {String? userId}) async {
    final current = getFavoriteSongs(userId: userId);
    // Prevent duplicate entries
    if (!current.any((s) => s.id == song.id)) {
      current.insert(0, song);
      await _cacheService.setJson(
        _songKey(userId),
        current.map((s) => s.toJson()).toList(),
      );
    }
  }

  @override
  Future<void> removeFavoriteSong(String favoriteId, {String? userId}) async {
    final current = getFavoriteSongs(userId: userId);
    current.removeWhere((s) => s.id == favoriteId);
    await _cacheService.setJson(
      _songKey(userId),
      current.map((s) => s.toJson()).toList(),
    );
  }

  @override
  Future<List<int>> mergeGuestFavorites({
    required String userId,
    bool isOnline = true,
  }) async {
    final guestStationIds = getLocalFavoriteStationIds(userId: null);
    final guestSongs = getFavoriteSongs(userId: null);
    final newlyMergedStationIds = <int>[];

    // 1. Merge Station Favorites
    if (guestStationIds.isNotEmpty) {
      final userStationIds = getLocalFavoriteStationIds(userId: userId);

      for (final id in guestStationIds) {
        if (!userStationIds.contains(id)) {
          userStationIds.add(id);
          newlyMergedStationIds.add(id);
        }
      }
      await _saveLocalFavoriteStationIds(userStationIds, userId: userId);

      // If online, sync each newly merged station to the user's server account
      if (isOnline) {
        for (final stationId in newlyMergedStationIds) {
          try {
            await _apiClient.post(ApiEndpoints.favouriteStation(stationId));
          } catch (_) {
            // Pending sync service will retry
          }
        }
      }
    }

    // 2. Merge Song Favorites (strictly local)
    if (guestSongs.isNotEmpty) {
      final userSongs = getFavoriteSongs(userId: userId);
      for (final song in guestSongs) {
        if (!userSongs.any((s) => s.id == song.id)) {
          userSongs.add(song);
        }
      }
      await _cacheService.setJson(
        _songKey(userId),
        userSongs.map((s) => s.toJson()).toList(),
      );
    }

    // 3. Clear guest-scoped state only after successful merge!
    await _cacheService.remove(_stationKey(null));
    await _cacheService.remove(_songKey(null));

    return newlyMergedStationIds;
  }
}
