import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/core/network/api_endpoints.dart';
import 'package:pulsecast/core/network/api_exception.dart';
import 'package:pulsecast/features/admin/data/admin_song_repository.dart';
import '../../mocks/mock_api_client.dart';

void main() {
  group('AdminSongRepository Unit Tests', () {
    late MockApiClient mockApiClient;
    late AdminSongRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = AdminSongRepository(apiClient: mockApiClient);
    });

    test('getSongs parses Supabase songs list', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        expect(path, ApiEndpoints.adminSongs);
        expect(queryParameters?['page'], 1);
        expect(queryParameters?['search'], 'Massive');

        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'count': 1,
            'data': [
              {
                'id': '1a3825f2-1b65-4615-9f03-c42722d73551',
                'title': 'Teardrop',
                'artist': 'Massive Attack',
                'album': 'Mezzanine',
                'duration': '05:30',
                'duration_seconds': 330,
                'file_size_bytes': 7890123,
                'storage_bucket': 'pulsecast-music-library',
                'storage_path': 'library/1a3825f2-.../teardrop.mp3',
                'is_active': true,
              }
            ],
          },
        );
      };

      final songs = await repository.getSongs(search: 'Massive');

      expect(songs.length, 1);
      expect(songs.first.id, '1a3825f2-1b65-4615-9f03-c42722d73551');
      expect(songs.first.title, 'Teardrop');
    });

    test('getSongStats returns aggregated library stats', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        expect(path, ApiEndpoints.adminSongStats);
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'totalSongs': 7,
              'activeSongs': 7,
              'totalStorageBytes': 52428800,
              'totalDurationSeconds': 1540,
            },
          },
        );
      };

      final stats = await repository.getSongStats();

      expect(stats.totalSongs, 7);
      expect(stats.activeSongs, 7);
      expect(stats.totalStorageBytes, 52428800);
      expect(stats.formattedTotalStorage, '50.0 MB');
    });

    test('getSignedUrl returns ephemeral signed URL', () async {
      const songId = '1a3825f2-1b65-4615-9f03-c42722d73551';
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        expect(path, ApiEndpoints.adminSongSignedUrl(songId));
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'songId': songId,
              'title': 'Teardrop',
              'artist': 'Massive Attack',
              'signedUrl': 'https://supabase.co/storage/v1/object/sign/...',
              'expiresIn': 300,
            },
          },
        );
      };

      final signedUrl = await repository.getSignedUrl(songId);

      expect(signedUrl.songId, songId);
      expect(signedUrl.signedUrl, contains('https://supabase.co'));
      expect(signedUrl.expiresIn, 300);
      expect(signedUrl.isExpired, isFalse);
    });

    test('updateSong sends PATCH and returns updated AdminSong', () async {
      const songId = '1a3825f2-1b65-4615-9f03-c42722d73551';
      mockApiClient.onPatch = (path, {data, queryParameters, options}) async {
        expect(path, ApiEndpoints.adminSongDetail(songId));
        expect((data as Map)['title'], 'Teardrop (Remastered)');

        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'id': songId,
              'title': 'Teardrop (Remastered)',
              'artist': 'Massive Attack',
              'storage_bucket': 'pulsecast-music-library',
              'storage_path': '...',
              'is_active': true,
            },
          },
        );
      };

      final updated = await repository.updateSong(
        songId,
        title: 'Teardrop (Remastered)',
      );

      expect(updated.title, 'Teardrop (Remastered)');
    });

    test('deleteSong handles 409 conflict exception for scheduled songs', () async {
      const songId = '1a3825f2-1b65-4615-9f03-c42722d73551';
      mockApiClient.onDelete = (path, {data, queryParameters, options}) async {
        throw ApiException(
          statusCode: 409,
          message:
              'Cannot delete song: currently assigned to 2 program schedule(s). Archive it instead.',
        );
      };

      expect(
        () => repository.deleteSong(songId, permanent: true),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });
}
