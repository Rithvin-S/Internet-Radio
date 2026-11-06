import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../domain/models/admin_schedule.dart';
import '../domain/models/schedule_playlist_track.dart';

abstract class IAdminScheduleRepository {
  Future<List<AdminSchedule>> getSchedules({
    String? from,
    String? to,
    int? stationId,
    String? status,
  });

  Future<AdminSchedule> getScheduleById(int id);

  Future<AdminSchedule> createSchedule(AdminSchedule schedule);

  Future<AdminSchedule> updateSchedule(int id, AdminSchedule schedule);

  Future<void> deleteSchedule(int id);

  Future<AdminSchedule> duplicateSchedule(int id);

  Future<bool> togglePublishSchedule(int id);

  Future<List<SchedulePlaylistTrack>> getPlaylistTracks(int scheduleId);

  Future<List<SchedulePlaylistTrack>> updatePlaylistTracks(
    int scheduleId,
    List<SchedulePlaylistTrack> tracks,
  );

  Future<void> deletePlaylistTrack(int scheduleId, String trackId);
}

class AdminScheduleRepository implements IAdminScheduleRepository {
  final ApiClient _apiClient;

  AdminScheduleRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<AdminSchedule>> getSchedules({
    String? from,
    String? to,
    int? stationId,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{};
    if (from != null) queryParams['from'] = from;
    if (to != null) queryParams['to'] = to;
    if (stationId != null) queryParams['stationId'] = stationId;
    if (status != null) queryParams['status'] = status;

    final response = await _apiClient.get(
      ApiEndpoints.adminSchedules,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => AdminSchedule.fromJson(item))
          .toList();
    }
    return [];
  }

  @override
  Future<AdminSchedule> getScheduleById(int id) async {
    final response = await _apiClient.get(ApiEndpoints.adminScheduleDetail(id));
    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return AdminSchedule.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException(message: 'Schedule not found', statusCode: 404);
  }

  @override
  Future<AdminSchedule> createSchedule(AdminSchedule schedule) async {
    final body = {
      'station_id': schedule.stationId,
      'title': schedule.title,
      if (schedule.description != null) 'description': schedule.description,
      if (schedule.category != null) 'category': schedule.category,
      'schedule_date': schedule.scheduleDate,
      'start_time': schedule.startTime,
      'end_time': schedule.endTime,
      'is_published': schedule.isPublished,
      'is_recurring': schedule.isRecurring,
      'songs': schedule.songs.map((s) => s.toBatchJson()).toList(),
    };

    final response = await _apiClient.post(
      ApiEndpoints.adminSchedules,
      data: body,
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return AdminSchedule.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException(message: 'Failed to create schedule');
  }

  @override
  Future<AdminSchedule> updateSchedule(int id, AdminSchedule schedule) async {
    final body = {
      'station_id': schedule.stationId,
      'title': schedule.title,
      if (schedule.description != null) 'description': schedule.description,
      if (schedule.category != null) 'category': schedule.category,
      'schedule_date': schedule.scheduleDate,
      'start_time': schedule.startTime,
      'end_time': schedule.endTime,
      'is_published': schedule.isPublished,
      'is_recurring': schedule.isRecurring,
      'songs': schedule.songs.map((s) => s.toBatchJson()).toList(),
    };

    final response = await _apiClient.put(
      ApiEndpoints.adminScheduleDetail(id),
      data: body,
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return AdminSchedule.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException(message: 'Failed to update schedule');
  }

  @override
  Future<void> deleteSchedule(int id) async {
    await _apiClient.delete(ApiEndpoints.adminScheduleDetail(id));
  }

  @override
  Future<AdminSchedule> duplicateSchedule(int id) async {
    final response = await _apiClient.post(
      ApiEndpoints.adminScheduleDuplicate(id),
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return AdminSchedule.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException(message: 'Failed to duplicate schedule');
  }

  @override
  Future<bool> togglePublishSchedule(int id) async {
    final response = await _apiClient.patch(
      ApiEndpoints.adminSchedulePublish(id),
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['is_published'] is bool) {
      return data['is_published'] as bool;
    }
    return true;
  }

  @override
  Future<List<SchedulePlaylistTrack>> getPlaylistTracks(int scheduleId) async {
    final response = await _apiClient.get(
      ApiEndpoints.adminScheduleTracks(scheduleId),
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => SchedulePlaylistTrack.fromJson(item))
          .toList();
    }
    return [];
  }

  @override
  Future<List<SchedulePlaylistTrack>> updatePlaylistTracks(
    int scheduleId,
    List<SchedulePlaylistTrack> tracks,
  ) async {
    final body = {
      'tracks': tracks.map((t) => t.toBatchJson()).toList(),
    };

    final response = await _apiClient.put(
      ApiEndpoints.adminScheduleTracks(scheduleId),
      data: body,
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => SchedulePlaylistTrack.fromJson(item))
          .toList();
    }
    return tracks;
  }

  @override
  Future<void> deletePlaylistTrack(int scheduleId, String trackId) async {
    await _apiClient.delete(
      ApiEndpoints.adminScheduleTrackDelete(scheduleId, trackId),
    );
  }
}
