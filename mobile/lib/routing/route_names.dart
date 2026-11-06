/// Centralized Route Name Definitions for GoRouter
class RouteNames {
  RouteNames._();

  static const String home = '/';
  static const String radio = '/';
  static const String stations = '/stations';
  static const String stationDetails = '/stations/:id';
  static const String player = '/player';
  static const String library = '/library';
  static const String favourites = '/favourites';
  static const String settings = '/settings';
  static const String schedules = '/schedules';

  // Auth Routes
  static const String login = '/login';
  static const String register = '/register';

  // Admin Routes
  static const String admin = '/admin';
  static const String adminSongs = '/admin/songs';
  static const String adminSongUpload = '/admin/songs/upload';
  static const String adminSchedules = '/admin/schedules';
  static const String adminStations = '/admin/stations';
}

