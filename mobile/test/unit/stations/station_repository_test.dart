import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulsecast/core/cache/cache_policy.dart';
import 'package:pulsecast/core/cache/cache_service.dart';
import 'package:pulsecast/core/network/api_endpoints.dart';
import 'package:pulsecast/core/network/api_exception.dart';
import 'package:pulsecast/features/stations/data/station_repository.dart';
import '../../mocks/mock_api_client.dart';

void main() {
  group('StationRepository Unit Tests', () {
    late MockApiClient mockApiClient;
    late StationRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = StationRepository(apiClient: mockApiClient);
    });

    test('Station API success: parses station list and filters', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        expect(path, ApiEndpoints.stations);
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'count': 3,
            'data': [
              {
                'id': 1,
                'name': 'Radio Paradise (Main Mix)',
                'description': 'High-fidelity eclectic rock.',
                'genre': 'Eclectic / Rock',
                'stream_url': 'https://stream.radioparadise.com/mp3-128',
                'artwork_url': 'https://stream.radioparadise.com/logo.png',
                'is_active': true,
                'is_favourite': false,
              },
              {
                'id': 6,
                'name': 'PulseCast Radio (Dev)',
                'description': 'Local loopback station',
                'genre': 'Mixed',
                'stream_url': 'http://localhost:8000/pulsecast.mp3',
                'is_active': true,
                'is_favourite': false,
              },
              {
                'id': 7,
                'name': 'PulseCast Radio (AWS)',
                'description': 'Live EC2 Icecast stream',
                'genre': 'Mixed',
                'stream_url': 'https://pulsecast.duckdns.org/pulsecast.mp3',
                'is_active': true,
                'is_favourite': true,
              },
            ],
          },
        );
      };

      final stations = await repository.getStations();
      expect(stations.length, 3);

      // Station 1: External station parsing
      expect(stations[0].id, 1);
      expect(stations[0].name, 'Radio Paradise (Main Mix)');
      expect(stations[0].isLocalFallback, isFalse);
      expect(stations[0].isPrimaryAwsStream, isFalse);

      // Station 6: Local fallback station identification
      expect(stations[1].id, 6);
      expect(stations[1].isLocalFallback, isTrue);

      // Station 7: Primary AWS EC2 Icecast station
      expect(stations[2].id, 7);
      expect(stations[2].isPrimaryAwsStream, isTrue);
      expect(stations[2].isFavourite, isTrue);
    });

    test('Station API failure: throws ApiException with message', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        throw ApiException(
          message: 'Server unreachable',
          statusCode: 503,
        );
      };

      expect(
        () => repository.getStations(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)),
      );
    });

    test('Empty station response: returns empty list', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {'success': true, 'count': 0, 'data': []},
        );
      };

      final stations = await repository.getStations();
      expect(stations, isEmpty);
    });

    test('getStationById returns single station correctly', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        expect(path, '${ApiEndpoints.stations}/7');
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'id': 7,
              'name': 'PulseCast Radio (AWS)',
              'genre': 'Mixed',
              'stream_url': 'https://pulsecast.duckdns.org/pulsecast.mp3',
            },
          },
        );
      };

      final station = await repository.getStationById(7);
      expect(station.id, 7);
      expect(station.name, 'PulseCast Radio (AWS)');
      expect(station.streamUrl, 'https://pulsecast.duckdns.org/pulsecast.mp3');
    });

    test('Fast cache path: returns cached stations immediately when valid and revalidates in background', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cacheService = CacheService(prefs);

      // Pre-populate cache
      await cacheService.setJson(
        CachePolicy.keyStationsList,
        [
          {
            'id': 7,
            'name': 'PulseCast Radio (AWS)',
            'genre': 'Mixed',
            'stream_url': 'https://pulsecast.duckdns.org/pulsecast.mp3',
          }
        ],
        ttl: const Duration(hours: 24),
      );

      bool apiCalled = false;
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        apiCalled = true;
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {'success': true, 'data': []},
        );
      };

      final cachedRepo = StationRepository(
        apiClient: mockApiClient,
        cacheService: cacheService,
      );

      final stations = await cachedRepo.getStations();
      expect(stations.length, 1);
      expect(stations.first.id, 7);
      expect(stations.first.name, 'PulseCast Radio (AWS)');

      // Background revalidation was triggered
      await pumpEventQueue();
      expect(apiCalled, isTrue);
    });
  });
}

