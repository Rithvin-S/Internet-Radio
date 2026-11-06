import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/core/network/api_endpoints.dart';
import 'package:pulsecast/features/player/data/now_playing_repository.dart';
import '../../mocks/mock_api_client.dart';

void main() {
  group('NowPlayingRepository Unit Tests', () {
    late MockApiClient mockApiClient;
    late NowPlayingRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = NowPlayingRepository(apiClient: mockApiClient);
    });

    test('parses now-playing track and up-next playlist queue', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        if (path == '${ApiEndpoints.stations}/1/tracks') {
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: {
              'success': true,
              'station': {'id': 1, 'name': 'Radio Paradise'},
              'now_playing': {
                'id': 1,
                'title': 'Teardrop',
                'artist': 'Massive Attack',
                'album': 'Mezzanine',
                'duration': '05:30',
              },
              'up_next': [
                {
                  'id': 2,
                  'title': 'Karma Police',
                  'artist': 'Radiohead',
                  'duration': '04:24',
                },
                {
                  'id': 3,
                  'title': 'Drive',
                  'artist': 'R.E.M.',
                  'duration': '04:31',
                },
              ],
            },
          );
        } else if (path == '/api/streaming/stations/1/current-broadcast') {
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: {
              'success': true,
              'station_id': 1,
              'has_schedule': true,
              'schedule': {
                'id': 1,
                'title': 'Morning Acoustic Awakening',
                'start_time': '09:00',
                'end_time': '12:00',
              },
            },
          );
        }
        throw Exception('Not found');
      };

      final info = await repository.getNowPlaying(1);
      expect(info, isNotNull);
      expect(info!.stationId, 1);
      expect(info.title, 'Teardrop');
      expect(info.artist, 'Massive Attack');
      expect(info.album, 'Mezzanine');
      expect(info.programTitle, 'Morning Acoustic Awakening');
      expect(info.startTime, '09:00');
      expect(info.endTime, '12:00');
      expect(info.upNext.length, 2);
      expect(info.upNext[0].title, 'Karma Police');
      expect(info.upNext[1].title, 'Drive');
    });

    test('handles stations with no schedule or playlist gracefully', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        // External station without custom track playlist
        throw Exception('404 Not Found');
      };

      final info = await repository.getNowPlaying(5);
      expect(info, isNull);
    });
  });
}

