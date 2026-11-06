import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/models/admin_dashboard_stats.dart';
import '../domain/models/admin_song_stats.dart';
import 'admin_schedule_repository.dart';
import 'admin_song_repository.dart';
import 'admin_station_repository.dart';

abstract class IAdminDashboardRepository {
  Future<AdminDashboardStats> getDashboardStats();
}

class AdminDashboardRepository implements IAdminDashboardRepository {
  final ApiClient _apiClient;
  final IAdminSongRepository _songRepo;
  final IAdminStationRepository _stationRepo;
  final IAdminScheduleRepository _scheduleRepo;

  AdminDashboardRepository({
    required ApiClient apiClient,
    required IAdminSongRepository songRepo,
    required IAdminStationRepository stationRepo,
    required IAdminScheduleRepository scheduleRepo,
  })  : _apiClient = apiClient,
        _songRepo = songRepo,
        _stationRepo = stationRepo,
        _scheduleRepo = scheduleRepo;

  @override
  Future<AdminDashboardStats> getDashboardStats() async {
    AdminSongStats? songStats;
    int totalStations = 0;
    int activeStations = 0;
    int totalSchedules = 0;
    int publishedSchedules = 0;
    String serverStatus = 'online';

    // 1. Song statistics
    try {
      songStats = await _songRepo.getSongStats();
    } catch (_) {}

    // 2. Stations
    try {
      final stations = await _stationRepo.getStations(all: true);
      totalStations = stations.length;
      activeStations = stations.where((s) => s.isActive).length;
    } catch (_) {}

    // 3. Schedules
    try {
      final schedules = await _scheduleRepo.getSchedules();
      totalSchedules = schedules.length;
      publishedSchedules = schedules.where((s) => s.isPublished).length;
    } catch (_) {}

    // 4. Server health
    try {
      final healthRes = await _apiClient.get(ApiEndpoints.health);
      if (healthRes.statusCode != 200) {
        serverStatus = 'degraded';
      }
    } catch (_) {
      serverStatus = 'offline';
    }

    return AdminDashboardStats(
      songStats: songStats,
      totalStations: totalStations,
      activeStations: activeStations,
      totalSchedules: totalSchedules,
      publishedSchedules: publishedSchedules,
      serverStatus: serverStatus,
      lastChecked: DateTime.now(),
    );
  }
}
