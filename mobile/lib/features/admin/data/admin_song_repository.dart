import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../domain/models/admin_song.dart';
import '../domain/models/admin_song_stats.dart';
import '../domain/models/song_signed_url.dart';

abstract class IAdminSongRepository {
  Future<List<AdminSong>> getSongs({
    int page = 1,
    int limit = 50,
    String? search,
    bool? activeOnly,
    String? sortBy,
    String? order,
  });

  Future<AdminSongStats> getSongStats();

  Future<AdminSong> getSongById(String id);

  Future<AdminSong> uploadSong({
    required String filePath,
    String? title,
    String? artist,
    String? album,
    void Function(int sent, int total)? onProgress,
  });

  Future<Map<String, dynamic>> bulkUploadSongs({
    required List<String> filePaths,
    int concurrency = 3,
    void Function(int sent, int total)? onProgress,
  });

  Future<AdminSong> updateSong(
    String id, {
    String? title,
    String? artist,
    String? album,
    bool? isActive,
  });

  Future<void> deleteSong(
    String id, {
    bool permanent = false,
    bool force = false,
  });

  Future<SongSignedUrl> getSignedUrl(String id, {int expiresIn = 300});

  Future<List<Map<String, dynamic>>> searchCatalogue(
    String query, {
    String source = 'all',
  });
}

class AdminSongRepository implements IAdminSongRepository {
  final ApiClient _apiClient;

  AdminSongRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<List<AdminSong>> getSongs({
    int page = 1,
    int limit = 50,
    String? search,
    bool? activeOnly,
    String? sortBy,
    String? order,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (activeOnly != null) {
      queryParams['activeOnly'] = activeOnly;
    }
    if (sortBy != null) {
      queryParams['sortBy'] = sortBy;
    }
    if (order != null) {
      queryParams['order'] = order;
    }

    final response = await _apiClient.get(
      ApiEndpoints.adminSongs,
      queryParameters: queryParams,
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => AdminSong.fromJson(item))
          .toList();
    }
    return [];
  }

  @override
  Future<AdminSongStats> getSongStats() async {
    final response = await _apiClient.get(ApiEndpoints.adminSongStats);
    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return AdminSongStats.fromJson(data['data'] as Map<String, dynamic>);
    }
    return const AdminSongStats();
  }

  @override
  Future<AdminSong> getSongById(String id) async {
    final response = await _apiClient.get(ApiEndpoints.adminSongDetail(id));
    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return AdminSong.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException(
      message: 'Song not found',
      statusCode: 404,
    );
  }

  @override
  Future<AdminSong> uploadSong({
    required String filePath,
    String? title,
    String? artist,
    String? album,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw ApiException(message: 'File does not exist: $filePath');
    }

    final fileName = filePath.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (artist != null && artist.trim().isNotEmpty) 'artist': artist.trim(),
      if (album != null && album.trim().isNotEmpty) 'album': album.trim(),
    });

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.adminSongs,
        data: formData,
        onSendProgress: onProgress,
      );

      final dynamic data = response.data;
      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
        return AdminSong.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ApiException(message: 'Upload succeeded but no song data returned.');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> bulkUploadSongs({
    required List<String> filePaths,
    int concurrency = 3,
    void Function(int sent, int total)? onProgress,
  }) async {
    final List<MultipartFile> files = [];
    for (final path in filePaths) {
      final fileName = path.split(Platform.pathSeparator).last;
      files.add(await MultipartFile.fromFile(path, filename: fileName));
    }

    final formData = FormData.fromMap({
      'files': files,
      'concurrency': concurrency,
    });

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.adminSongBulk,
        data: formData,
        onSendProgress: onProgress,
      );

      return response.data as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<AdminSong> updateSong(
    String id, {
    String? title,
    String? artist,
    String? album,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (artist != null) body['artist'] = artist;
    if (album != null) body['album'] = album;
    if (isActive != null) body['is_active'] = isActive;

    final response = await _apiClient.patch(
      ApiEndpoints.adminSongDetail(id),
      data: body,
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return AdminSong.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException(message: 'Failed to update song metadata');
  }

  @override
  Future<void> deleteSong(
    String id, {
    bool permanent = false,
    bool force = false,
  }) async {
    final queryParams = <String, dynamic>{
      if (permanent) 'permanent': 'true',
      if (force) 'force': 'true',
    };

    await _apiClient.delete(
      ApiEndpoints.adminSongDetail(id),
      queryParameters: queryParams,
    );
  }

  @override
  Future<SongSignedUrl> getSignedUrl(String id, {int expiresIn = 300}) async {
    final response = await _apiClient.get(
      ApiEndpoints.adminSongSignedUrl(id),
      queryParameters: {'expiresIn': expiresIn},
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return SongSignedUrl.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException(message: 'Failed to generate signed URL');
  }

  @override
  Future<List<Map<String, dynamic>>> searchCatalogue(
    String query, {
    String source = 'all',
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.adminSongSearch,
      queryParameters: {
        'q': query,
        'source': source,
      },
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }
}
