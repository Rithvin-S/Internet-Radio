import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/core/network/api_endpoints.dart';
import 'package:pulsecast/core/network/api_exception.dart';
import 'package:pulsecast/features/admin/data/admin_schedule_repository.dart';
import 'package:pulsecast/features/admin/domain/models/admin_schedule.dart';
import '../../mocks/mock_api_client.dart';

void main() {
  group('AdminScheduleRepository Unit Tests', () {
    late MockApiClient mockApiClient;
    late AdminScheduleRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = AdminScheduleRepository(apiClient: mockApiClient);
    });

    test('getSchedules parses schedule list with assigned song counts', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        expect(path, ApiEndpoints.adminSchedules);
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'count': 1,
            'data': [
              {
                'id': 1,
                'station_id': 1,
                'station_name': 'Radio Paradise',
                'title': 'Morning Acoustic Awakening',
                'schedule_date': '2026-10-31',
                'start_time': '09:00',
                'end_time': '12:00',
                'is_published': true,
                'song_count': 5,
              }
            ],
          },
        );
      };

      final schedules = await repository.getSchedules();

      expect(schedules.length, 1);
      expect(schedules.first.title, 'Morning Acoustic Awakening');
      expect(schedules.first.songCount, 5);
      expect(schedules.first.isPublished, isTrue);
    });

    test('createSchedule detects 409 overlapping conflict error', () async {
      const schedule = AdminSchedule(
        id: 0,
        stationId: 1,
        title: 'Conflicting Programme',
        scheduleDate: '2026-11-02',
        startTime: '10:00',
        endTime: '12:00',
      );

      mockApiClient.onPost = (path, {data, queryParameters, options}) async {
        throw ApiException(
          statusCode: 409,
          message:
              'Schedule conflict: Overlaps with existing published programme "Morning Acoustic Awakening" (09:00 - 12:00) on this station.',
        );
      };

      expect(
        () => repository.createSchedule(schedule),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('duplicateSchedule duplicates schedule as draft', () async {
      mockApiClient.onPost = (path, {data, queryParameters, options}) async {
        expect(path, ApiEndpoints.adminScheduleDuplicate(1));
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 201,
          data: {
            'success': true,
            'data': {
              'id': 2,
              'station_id': 1,
              'title': 'Copy of Morning Acoustic Awakening',
              'schedule_date': '2026-10-31',
              'start_time': '09:00',
              'end_time': '12:00',
              'is_published': false,
              'status': 'draft',
            },
          },
        );
      };

      final duplicated = await repository.duplicateSchedule(1);

      expect(duplicated.id, 2);
      expect(duplicated.title, 'Copy of Morning Acoustic Awakening');
      expect(duplicated.isPublished, isFalse);
    });

    test('togglePublishSchedule sends PATCH to publish endpoint', () async {
      mockApiClient.onPatch = (path, {data, queryParameters, options}) async {
        expect(path, ApiEndpoints.adminSchedulePublish(1));
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'is_published': true,
          },
        );
      };

      final isPublished = await repository.togglePublishSchedule(1);

      expect(isPublished, isTrue);
    });

    test('getPlaylistTracks preserves General vs Supabase track sources', () async {
      mockApiClient.onGet = (path, {queryParameters, options}) async {
        expect(path, ApiEndpoints.adminScheduleTracks(1));
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'count': 2,
            'data': [
              {
                'id': 'c1',
                'schedule_id': 1,
                'song_id': '1a3825f2-uuid',
                'track_id': null,
                'source': 'supabase',
                'title': 'Teardrop',
                'artist': 'Massive Attack',
                'play_order': 1,
              },
              {
                'id': 'c2',
                'schedule_id': 1,
                'song_id': null,
                'track_id': 2,
                'source': 'general',
                'title': 'Karma Police',
                'artist': 'Radiohead',
                'play_order': 2,
              },
            ],
          },
        );
      };

      final tracks = await repository.getPlaylistTracks(1);

      expect(tracks.length, 2);
      expect(tracks[0].isSupabase, isTrue);
      expect(tracks[0].songId, '1a3825f2-uuid');
      expect(tracks[1].isGeneral, isTrue);
      expect(tracks[1].trackId, 2);
    });

    test('deletePlaylistTrack sends DELETE for track ID', () async {
      var deleted = false;
      mockApiClient.onDelete = (path, {data, queryParameters, options}) async {
        expect(path, ApiEndpoints.adminScheduleTrackDelete(1, 'c1'));
        deleted = true;
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {'success': true},
        );
      };

      await repository.deletePlaylistTrack(1, 'c1');

      expect(deleted, isTrue);
    });
  });
}
