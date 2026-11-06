/// PulseCast Backend API Endpoints (matching backend route definitions)
class ApiEndpoints {
  ApiEndpoints._();

  // Health
  static const String health = '/api/health';

  // Authentication
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String logout = '/api/auth/logout';
  static const String me = '/api/auth/me';

  // Stations & Live Streams
  static const String stations = '/api/stations';
  static String stationDetail(int id) => '/api/stations/$id';
  static String stationTracks(int id) => '/api/stations/$id/tracks';
  static String stationSchedules(int id) => '/api/stations/$id/schedules';
  static const String currentBroadcast = '/api/stations/broadcast/current';
  static const String stationSchedule = '/api/stations/schedule';

  // Streaming Bridge
  static String currentBroadcastStream(int stationId) =>
      '/api/streaming/stations/$stationId/current-broadcast';
  static String nextTrackStream(int stationId) =>
      '/api/streaming/stations/$stationId/next-track';

  // Favourites
  static const String favourites = '/api/favourites';
  static String favouriteStation(int stationId) => '/api/favourites/$stationId';

  // Admin Stations Management
  static const String adminStations = '/api/admin/stations';
  static String adminStationDetail(int id) => '/api/admin/stations/$id';
  static String adminStationStatus(int id) => '/api/admin/stations/$id/status';

  // Admin Songs (Supabase Storage Music Library)
  static const String adminSongs = '/api/admin/songs';
  static const String adminSongStats = '/api/admin/songs/stats';
  static const String adminSongBulk = '/api/admin/songs/bulk';
  static const String adminSongSearch = '/api/admin/songs/search';
  static String adminSongDetail(String id) => '/api/admin/songs/$id';
  static String adminSongSignedUrl(String id) => '/api/admin/songs/$id/signed-url';

  // Admin Program Schedules
  static const String adminSchedules = '/api/admin/schedules';
  static String adminScheduleDetail(int id) => '/api/admin/schedules/$id';
  static String adminScheduleDuplicate(int id) => '/api/admin/schedules/$id/duplicate';
  static String adminSchedulePublish(int id) => '/api/admin/schedules/$id/publish';

  // Admin Schedule Playlist Management
  static String adminScheduleTracks(int id) => '/api/admin/schedules/$id/tracks';
  static String adminScheduleTrackDelete(int scheduleId, String trackId) =>
      '/api/admin/schedules/$scheduleId/tracks/$trackId';

  // Admin Track Queue Management
  static String adminStationTracks(int stationId) =>
      '/api/admin/stations/$stationId/tracks';
  static String adminTrackStatus(int trackId) =>
      '/api/admin/tracks/$trackId/status';
  static String adminTrackDelete(int trackId) => '/api/admin/tracks/$trackId';
}

