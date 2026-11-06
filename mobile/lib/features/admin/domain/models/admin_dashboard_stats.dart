import 'admin_song_stats.dart';

class AdminDashboardStats {
  final AdminSongStats? songStats;
  final int totalStations;
  final int activeStations;
  final int totalSchedules;
  final int publishedSchedules;
  final String serverStatus;
  final DateTime lastChecked;

  const AdminDashboardStats({
    this.songStats,
    this.totalStations = 0,
    this.activeStations = 0,
    this.totalSchedules = 0,
    this.publishedSchedules = 0,
    this.serverStatus = 'online',
    required this.lastChecked,
  });

  bool get isServerHealthy => serverStatus.toLowerCase() == 'online';
}
