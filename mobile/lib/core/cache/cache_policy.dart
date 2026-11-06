/// Policies and keys governing offline caching TTLs and storage
class CachePolicy {
  CachePolicy._();

  // Storage Keys
  static const String keyStationsList = 'pulsecast_cache_stations_list';
  static const String keyStationPrefix = 'pulsecast_cache_station_';
  static const String keyListenerTracks = 'pulsecast_cache_listener_tracks';
  static const String keySchedulesList = 'pulsecast_cache_schedules_list';
  static const String keyLastSelectedStation = 'pulsecast_cache_last_selected_station';
  static const String keyUserPreferences = 'pulsecast_cache_user_preferences';
  static const String keySyncQueue = 'pulsecast_cache_sync_queue';
  static const String keyFavoritesStationsPrefix = 'pulsecast_fav_stations_';
  static const String keyFavoritesSongsPrefix = 'pulsecast_fav_songs_';

  // Cache Time-To-Live (TTL) Durations
  static const Duration stationsTtl = Duration(hours: 12);
  static const Duration stationDetailTtl = Duration(hours: 6);
  static const Duration listenerTracksTtl = Duration(hours: 2);
  static const Duration schedulesTtl = Duration(minutes: 30);

  /// List of cache keys that can be safely flushed during "Clear Cache"
  /// without deleting user settings, offline favorites, or auth sessions.
  static const List<String> nonEssentialCacheKeys = [
    keyStationsList,
    keyListenerTracks,
    keySchedulesList,
  ];
}

