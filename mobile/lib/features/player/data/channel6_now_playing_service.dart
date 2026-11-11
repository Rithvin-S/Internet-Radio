import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:pulsecast/core/config/app_config.dart';
import 'package:pulsecast/features/player/domain/models/channel6_now_playing.dart';

/// Fetches currently playing track metadata directly from the Channel 6
/// Node.js streaming server (`GET /api/now-playing`), isolated from main
/// backend auth interceptors and audio playback handlers.
class Channel6NowPlayingService {
  final Dio _dio;

  Channel6NowPlayingService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: const {
                  'User-Agent': AppConfig.userAgent,
                  'Accept': 'application/json',
                },
                responseType: ResponseType.json,
              ),
            );

  /// Queries `GET /api/now-playing` on Channel 6 and returns the active track
  /// if available, or `null` if the server has no active track.
  Future<Channel6NowPlayingTrack?> fetchNowPlaying({String? streamUrl}) async {
    final url = AppConfig.channel6NowPlayingUrlFor(streamUrl);
    final response = await _dio.get<dynamic>(url);
    final raw = response.data;

    Map<String, dynamic>? payload;
    if (raw is Map<String, dynamic>) {
      payload = raw;
    } else if (raw is Map) {
      payload = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        payload = Map<String, dynamic>.from(decoded);
      }
    }

    if (payload == null) return null;
    return Channel6NowPlayingTrack.tryFromJson(payload);
  }
}

