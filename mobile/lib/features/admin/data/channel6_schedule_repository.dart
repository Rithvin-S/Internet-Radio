import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/models/channel6_schedule_state.dart';

abstract class IChannel6ScheduleRepository {
  Future<Channel6ScheduleState> getSchedule({String? streamUrl});
  Future<Channel6ScheduleState> enqueueTrack(
    String trackId, {
    String? streamUrl,
  });
  Future<Channel6ScheduleState> enqueueTracks(
    List<String> trackIds, {
    String? streamUrl,
  });
  Future<Channel6ScheduleState> reorderQueue(
    List<String> orderedItemIds, {
    String? streamUrl,
  });
  Future<Channel6ScheduleState> removeQueueItem(
    String itemId, {
    String? streamUrl,
  });
  Future<Channel6ScheduleState> clearQueue({String? streamUrl});
  Future<Channel6ScheduleState> rescanLibrary({String? streamUrl});
}

/// Communicates with Channel 6 Node.js streamer admin queue endpoints using the
/// signed-in administrator's session JWT (never stores or embeds secret keys).
class Channel6ScheduleRepository implements IChannel6ScheduleRepository {
  final SecureStorageService _storageService;
  final Dio _dio;

  Channel6ScheduleRepository({
    required SecureStorageService storageService,
    Dio? dio,
  })  : _storageService = storageService,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(
                  milliseconds: AppConfig.connectTimeout,
                ),
                receiveTimeout: const Duration(
                  milliseconds: AppConfig.receiveTimeout,
                ),
                headers: const {
                  'User-Agent': AppConfig.userAgent,
                  'Accept': 'application/json',
                },
                responseType: ResponseType.json,
              ),
            );

  Future<Options> _authOptions() async {
    final token = await _storageService.getToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        message: 'Administrator session not found. Please sign in again.',
        statusCode: 401,
      );
    }
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  Channel6ScheduleState _parseStateResponse(Response<dynamic> response) {
    final raw = response.data;
    Map<String, dynamic>? map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        map = Map<String, dynamic>.from(decoded);
      }
    }
    if (map == null) {
      throw const ApiException(
        message: 'Invalid response received from Channel 6 scheduler.',
      );
    }
    return Channel6ScheduleState.fromJson(map);
  }

  ApiException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? serverMsg;
    if (data is Map && data['message'] != null) {
      serverMsg = data['message'].toString();
    }
    if (status == 401) {
      return ApiException(
        message:
            serverMsg ?? 'Administrator session expired. Please sign in again.',
        statusCode: 401,
      );
    }
    if (status == 403) {
      return ApiException(
        message:
            serverMsg ?? 'Access denied. Administrator privileges required.',
        statusCode: 403,
      );
    }
    if (serverMsg != null && serverMsg.isNotEmpty) {
      return ApiException(message: serverMsg, statusCode: status);
    }
    return ApiException.fromDioError(e);
  }

  Future<Channel6ScheduleState> _request(
    String method,
    String path, {
    String? streamUrl,
    dynamic data,
  }) async {
    final baseUrl = AppConfig.channel6BaseUrlFor(streamUrl);
    final url = '$baseUrl$path';
    final options = await _authOptions();
    options.method = method;

    try {
      final response = await _dio.request<dynamic>(
        url,
        data: data,
        options: options,
      );
      return _parseStateResponse(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<Channel6ScheduleState> getSchedule({String? streamUrl}) {
    return _request('GET', '/api/admin/channel6/schedule', streamUrl: streamUrl);
  }

  @override
  Future<Channel6ScheduleState> enqueueTrack(
    String trackId, {
    String? streamUrl,
  }) {
    return _request(
      'POST',
      '/api/admin/channel6/queue',
      streamUrl: streamUrl,
      data: {'trackId': trackId},
    );
  }

  @override
  Future<Channel6ScheduleState> enqueueTracks(
    List<String> trackIds, {
    String? streamUrl,
  }) {
    return _request(
      'POST',
      '/api/admin/channel6/queue',
      streamUrl: streamUrl,
      data: {'trackIds': trackIds},
    );
  }

  @override
  Future<Channel6ScheduleState> reorderQueue(
    List<String> orderedItemIds, {
    String? streamUrl,
  }) {
    return _request(
      'PUT',
      '/api/admin/channel6/queue/reorder',
      streamUrl: streamUrl,
      data: {'orderedItemIds': orderedItemIds},
    );
  }

  @override
  Future<Channel6ScheduleState> removeQueueItem(
    String itemId, {
    String? streamUrl,
  }) {
    return _request(
      'DELETE',
      '/api/admin/channel6/queue/${Uri.encodeComponent(itemId)}',
      streamUrl: streamUrl,
    );
  }

  @override
  Future<Channel6ScheduleState> clearQueue({String? streamUrl}) {
    return _request(
      'DELETE',
      '/api/admin/channel6/queue',
      streamUrl: streamUrl,
    );
  }

  @override
  Future<Channel6ScheduleState> rescanLibrary({String? streamUrl}) {
    return _request(
      'POST',
      '/api/admin/channel6/rescan',
      streamUrl: streamUrl,
    );
  }
}
