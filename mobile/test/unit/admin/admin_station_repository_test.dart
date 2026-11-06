import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/core/network/api_endpoints.dart';
import 'package:pulsecast/features/admin/data/admin_station_repository.dart';
import '../../mocks/mock_api_client.dart';

void main() {
  group('AdminStationRepository Unit Tests', () {
    late MockApiClient mockApiClient;
    late AdminStationRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = AdminStationRepository(apiClient: mockApiClient);
    });

    test('getStations with all=true includes inactive stations', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        expect(path, ApiEndpoints.stations);
        expect(queryParameters?['all'], 'true');

        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'count': 2,
            'data': [
              {
                'id': 1,
                'name': 'Radio Paradise',
                'stream_url': 'https://stream.radioparadise.com/mp3-128',
                'is_active': true,
              },
              {
                'id': 8,
                'name': 'Chillhop Beats',
                'stream_url': 'https://stream.chillhop.com/live.mp3',
                'is_active': false,
              },
            ],
          },
        );
      };

      final stations = await repository.getStations(all: true);

      expect(stations.length, 2);
      expect(stations[0].isActive, isTrue);
      expect(stations[1].isActive, isFalse);
    });

    test('createStation sends POST and returns new Station record', () async {
      mockApiClient.onPost = (path, {data, queryParameters, options}) async {
        expect(path, ApiEndpoints.adminStations);
        final map = data as Map;
        expect(map['name'], 'New Synth Station');
        expect(map['stream_url'], 'https://stream.synth.fm/live');

        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 201,
          data: {
            'success': true,
            'data': {
              'id': 9,
              'name': 'New Synth Station',
              'stream_url': 'https://stream.synth.fm/live',
              'genre': 'Synthwave',
              'is_active': true,
            },
          },
        );
      };

      final station = await repository.createStation(
        name: 'New Synth Station',
        streamUrl: 'https://stream.synth.fm/live',
        genre: 'Synthwave',
      );

      expect(station.id, 9);
      expect(station.name, 'New Synth Station');
      expect(station.genre, 'Synthwave');
    });

    test('toggleStationStatus sends PATCH to status endpoint', () async {
      mockApiClient.onPatch = (path, {data, queryParameters, options}) async {
        expect(path, ApiEndpoints.adminStationStatus(1));
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'data': {'id': 1, 'is_active': false},
          },
        );
      };

      final result = await repository.toggleStationStatus(1, isActive: false);

      expect(result, isFalse);
    });

    test('deleteStation sends DELETE to station endpoint', () async {
      var deleted = false;
      mockApiClient.onDelete = (path, {data, queryParameters, options}) async {
        expect(path, ApiEndpoints.adminStationDetail(1));
        deleted = true;
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {'success': true},
        );
      };

      await repository.deleteStation(1);

      expect(deleted, isTrue);
    });
  });
}
