import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/models/now_playing_info.dart';

abstract class INowPlayingRepository {
  Future<NowPlayingInfo?> getNowPlaying(int stationId);
}

class NowPlayingRepository implements INowPlayingRepository {
  final ApiClient _apiClient;

  NowPlayingRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<NowPlayingInfo?> getNowPlaying(int stationId) async {
    NowPlayingInfo? tracksInfo;
    NowPlayingInfo? broadcastInfo;

    // 1. Attempt to fetch station track playlist / now playing
    try {
      final tracksResponse = await _apiClient.get(
        '${ApiEndpoints.stations}/$stationId/tracks',
      );
      if (tracksResponse.data is Map<String, dynamic>) {
        tracksInfo = NowPlayingInfo.fromTracksJson(
          stationId,
          tracksResponse.data as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Third-party or external stations might not implement station track queues
    }

    // 2. Attempt to fetch active program schedule from streaming bridge
    try {
      final broadcastResponse = await _apiClient.get(
        '/api/streaming/stations/$stationId/current-broadcast',
      );
      if (broadcastResponse.data is Map<String, dynamic>) {
        broadcastInfo = NowPlayingInfo.fromBroadcastJson(
          stationId,
          broadcastResponse.data as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Non-scheduled stations return gracefully
    }

    if (tracksInfo != null && broadcastInfo != null) {
      return tracksInfo.merge(broadcastInfo);
    }
    return tracksInfo ?? broadcastInfo;
  }
}

