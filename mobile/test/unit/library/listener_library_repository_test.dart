import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/features/library/data/listener_library_repository.dart';
import 'package:pulsecast/features/stations/data/station_repository.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import '../../mocks/mock_api_client.dart';

class FakeStationRepository implements IStationRepository {
  final List<Station> stations;
  FakeStationRepository(this.stations);

  @override
  Future<List<Station>> getStations({
    bool all = false,
    String? genre,
    String? search,
  }) async => stations;

  @override
  Future<Station> getStationById(int id) async =>
      stations.firstWhere((s) => s.id == id);
}

void main() {
  group('ListenerLibraryRepository Unit Tests', () {
    late MockApiClient mockApiClient;
    late FakeStationRepository fakeStationRepo;
    late ListenerLibraryRepository repository;

    final testStations = [
      const Station(
        id: 1,
        name: 'Radio Paradise',
        streamUrl: 'https://stream.radioparadise.com/mp3-128',
      ),
      const Station(
        id: 2,
        name: 'Nightwave Plaza',
        streamUrl: 'https://radio.plaza.one/mp3',
      ),
    ];

    setUp(() {
      mockApiClient = MockApiClient();
      fakeStationRepo = FakeStationRepository(testStations);
      repository = ListenerLibraryRepository(
        apiClient: mockApiClient,
        stationRepository: fakeStationRepo,
      );
    });

    test('getStationTracks parses now_playing and up_next queue', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        if (path == '/api/stations/1/tracks') {
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: {
              'success': true,
              'station': {'id': 1, 'name': 'Radio Paradise'},
              'total_tracks': 3,
              'now_playing': {
                'id': 10,
                'station_id': 1,
                'title': 'Teardrop',
                'artist': 'Massive Attack',
                'album': 'Mezzanine',
                'duration': '05:30',
                'play_order': 1,
                'status': 'playing',
              },
              'up_next': [
                {
                  'id': 11,
                  'station_id': 1,
                  'title': 'Karma Police',
                  'artist': 'Radiohead',
                  'album': 'OK Computer',
                  'duration': '04:24',
                  'play_order': 2,
                  'status': 'queued',
                },
                {
                  'id': 12,
                  'station_id': 1,
                  'title': 'Breathe',
                  'artist': 'Pink Floyd',
                  'album': 'Dark Side',
                  'duration': '02:43',
                  'play_order': 3,
                  'status': 'queued',
                },
              ],
            },
          );
        }
        throw Exception('Unhandled: $path');
      };

      final tracks = await repository.getLibraryTracks(stationId: 1);

      expect(tracks.length, 3);
      expect(tracks[0].title, 'Teardrop');
      expect(tracks[0].isCurrentlyPlaying, isTrue);
      expect(tracks[1].title, 'Karma Police');
      expect(tracks[1].isQueued, isTrue);
      expect(tracks[2].title, 'Breathe');
    });

    test('getLibraryTracks aggregates tracks across all stations when stationId is null', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        if (path == '/api/stations/1/tracks') {
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: {
              'success': true,
              'now_playing': {
                'id': 1,
                'station_id': 1,
                'title': 'Track 1',
                'artist': 'Artist 1',
                'status': 'playing',
              },
              'up_next': [],
            },
          );
        } else if (path == '/api/stations/2/tracks') {
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: {
              'success': true,
              'now_playing': {
                'id': 2,
                'station_id': 2,
                'title': 'Track 2',
                'artist': 'Artist 2',
                'status': 'playing',
              },
              'up_next': [],
            },
          );
        }
        throw Exception('Unhandled: $path');
      };

      final allTracks = await repository.getLibraryTracks(stationId: null);

      expect(allTracks.length, 2);
      expect(allTracks[0].stationName, 'Radio Paradise');
      expect(allTracks[1].stationName, 'Nightwave Plaza');
    });

    test('searchLibrary filters by query across title, artist, album, and station name', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'now_playing': {
              'id': 1,
              'title': 'Teardrop',
              'artist': 'Massive Attack',
              'album': 'Mezzanine',
              'status': 'playing',
            },
            'up_next': [
              {
                'id': 2,
                'title': 'Karma Police',
                'artist': 'Radiohead',
                'album': 'OK Computer',
                'status': 'queued',
              },
            ],
          },
        );
      };

      final results = await repository.getLibraryTracks(
        stationId: 1,
        search: 'radiohead',
      );

      expect(results.length, 1);
      expect(results.first.title, 'Karma Police');
      expect(results.first.artist, 'Radiohead');
    });
  });
}
