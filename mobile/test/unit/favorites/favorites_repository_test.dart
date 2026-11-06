import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulsecast/core/cache/cache_service.dart';
import 'package:pulsecast/core/network/api_client.dart';
import 'package:pulsecast/features/favorites/data/favorites_repository.dart';
import 'package:pulsecast/features/favorites/domain/models/favorite_song.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';

import 'package:pulsecast/core/storage/secure_storage_service.dart';

class MockDioClient extends ApiClient {
  final List<String> requestedEndpoints = [];
  dynamic mockResponseData;
  int mockStatusCode = 200;

  MockDioClient() : super(storageService: SecureStorageService());

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    requestedEndpoints.add('GET $path');
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: mockResponseData as T?,
      statusCode: mockStatusCode,
    );
  }

  @override
  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    requestedEndpoints.add('POST $path');
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: mockResponseData as T?,
      statusCode: mockStatusCode,
    );
  }

  @override
  Future<Response<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    requestedEndpoints.add('DELETE $path');
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: mockResponseData as T?,
      statusCode: mockStatusCode,
    );
  }
}

void main() {
  group('FavoritesRepository Unit Tests', () {
    late SharedPreferences prefs;
    late CacheService cacheService;
    late MockDioClient mockDio;
    late FavoritesRepository repository;

    const testStation = Station(
      id: 2,
      name: 'Nightwave Plaza',
      genre: 'Vaporwave',
      streamUrl: 'https://radio.plaza.one/mp3',
      isActive: true,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      cacheService = CacheService(prefs);
      mockDio = MockDioClient();
      repository = FavoritesRepository(
        apiClient: mockDio,
        cacheService: cacheService,
      );
    });

    test('addFavoriteStation updates local cache and sends POST when online', () async {
      mockDio.mockStatusCode = 201;

      final success = await repository.addFavoriteStation(
        testStation,
        userId: 'user_42',
        isOnline: true,
      );

      expect(success, isTrue);
      expect(mockDio.requestedEndpoints, contains('POST /api/favourites/2'));

      final localIds = repository.getLocalFavoriteStationIds(userId: 'user_42');
      expect(localIds, contains(2));
    });

    test('removeFavoriteStation removes from local cache and sends DELETE when online', () async {
      await repository.addFavoriteStation(testStation, userId: 'user_42', isOnline: false);
      expect(repository.getLocalFavoriteStationIds(userId: 'user_42'), contains(2));

      mockDio.mockStatusCode = 200;
      final success = await repository.removeFavoriteStation(
        2,
        userId: 'user_42',
        isOnline: true,
      );

      expect(success, isTrue);
      expect(mockDio.requestedEndpoints, contains('DELETE /api/favourites/2'));
      expect(repository.getLocalFavoriteStationIds(userId: 'user_42'), isNot(contains(2)));
    });

    test('getFavoriteStations fetches from server when online and updates local cache', () async {
      mockDio.mockResponseData = {
        'success': true,
        'count': 1,
        'data': [
          {
            'id': 2,
            'name': 'Nightwave Plaza',
            'genre': 'Vaporwave',
            'stream_url': 'https://radio.plaza.one/mp3',
            'is_active': true,
          }
        ]
      };

      final stations = await repository.getFavoriteStations(
        userId: 'user_42',
        isOnline: true,
      );

      expect(stations.length, equals(1));
      expect(stations.first.name, equals('Nightwave Plaza'));
      expect(mockDio.requestedEndpoints, contains('GET /api/favourites'));

      final localIds = repository.getLocalFavoriteStationIds(userId: 'user_42');
      expect(localIds, contains(2));
    });

    test('Favorite songs are saved and retrieved locally with strict account scoping', () async {
      final song1 = FavoriteSong(
        id: 'general_1',
        source: 'general',
        trackId: 1,
        title: 'Teardrop',
        artist: 'Massive Attack',
        duration: '05:30',
        favoritedAt: DateTime.now(),
      );

      await repository.addFavoriteSong(song1, userId: 'user_A');
      expect(repository.getFavoriteSongs(userId: 'user_A').length, equals(1));

      // user_B must have isolated empty list (no data leak between accounts!)
      expect(repository.getFavoriteSongs(userId: 'user_B'), isEmpty);

      // Remove from user_A
      await repository.removeFavoriteSong(song1.id, userId: 'user_A');
      expect(repository.getFavoriteSongs(userId: 'user_A'), isEmpty);
    });

    test('mergeGuestFavorites merges guest stations and songs into account, then purges guest cache', () async {
      // 1. Setup guest favorites
      await repository.addFavoriteStation(testStation, userId: null, isOnline: false);
      final guestSong = FavoriteSong(
        id: 'general_55',
        source: 'general',
        trackId: 55,
        title: 'Starfruits Surf Rider',
        artist: 'Cornelius',
        favoritedAt: DateTime.now(),
      );
      await repository.addFavoriteSong(guestSong, userId: null);

      expect(repository.getLocalFavoriteStationIds(userId: null), contains(2));
      expect(repository.getFavoriteSongs(userId: null).length, equals(1));

      // 2. Perform merge into user_99
      final newlyMerged = await repository.mergeGuestFavorites(
        userId: 'user_99',
        isOnline: true,
      );

      expect(newlyMerged, contains(2));
      expect(mockDio.requestedEndpoints, contains('POST /api/favourites/2'));

      // Verify user_99 has merged records
      expect(repository.getLocalFavoriteStationIds(userId: 'user_99'), contains(2));
      expect(repository.getFavoriteSongs(userId: 'user_99').length, equals(1));

      // Verify guest-scoped entries are cleared after successful merge
      expect(repository.getLocalFavoriteStationIds(userId: null), isEmpty);
      expect(repository.getFavoriteSongs(userId: null), isEmpty);
    });

    test('Migrates legacy un-scoped pulsecast_fav_songs safely to account-scoped key', () async {
      final legacySongJson = [
        {
          'id': 'general_99',
          'source': 'general',
          'track_id': 99,
          'title': 'Legacy Track',
          'artist': 'Legacy Artist',
          'favorited_at': DateTime.now().toIso8601String(),
        }
      ];

      // Simulate existing legacy global key
      await cacheService.setJson('pulsecast_fav_songs', legacySongJson);
      expect(cacheService.has('pulsecast_fav_songs'), isTrue);

      // Accessing favorites as user_Z triggers automatic migration
      final songs = repository.getFavoriteSongs(userId: 'user_Z');
      expect(songs.length, equals(1));
      expect(songs.first.title, equals('Legacy Track'));

      // Verify legacy global key is safely removed
      expect(cacheService.has('pulsecast_fav_songs'), isFalse);

      // Verify data is now safely isolated in user_Z key
      final userZSongs = repository.getFavoriteSongs(userId: 'user_Z');
      expect(userZSongs.length, equals(1));

      // Another user (user_Y) has an empty list and does not see user_Z's migrated songs
      expect(repository.getFavoriteSongs(userId: 'user_Y'), isEmpty);
    });

    test('Migrates legacy un-scoped pulsecast_fav_stations safely to account-scoped key', () async {
      final legacyStationIds = [2, 5];

      await cacheService.setJson('pulsecast_fav_stations', legacyStationIds);
      expect(cacheService.has('pulsecast_fav_stations'), isTrue);

      final ids = repository.getLocalFavoriteStationIds(userId: 'user_X');
      expect(ids, containsAll([2, 5]));

      expect(cacheService.has('pulsecast_fav_stations'), isFalse);
      expect(repository.getLocalFavoriteStationIds(userId: 'user_W'), isEmpty);
    });
  });
}
