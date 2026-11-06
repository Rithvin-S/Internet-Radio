import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../stations/domain/models/station.dart';
import '../../data/admin_dashboard_repository.dart';
import '../../data/admin_schedule_repository.dart';
import '../../data/admin_song_repository.dart';
import '../../data/admin_station_repository.dart';
import '../../domain/models/admin_dashboard_stats.dart';
import '../../domain/models/admin_schedule.dart';
import '../../domain/models/admin_song.dart';
import '../../domain/models/admin_song_stats.dart';
import '../../domain/models/schedule_playlist_track.dart';

// --- Repository Providers ---

final adminSongRepositoryProvider = Provider<IAdminSongRepository>((ref) {
  return AdminSongRepository(apiClient: ref.watch(apiClientProvider));
});

final adminStationRepositoryProvider = Provider<IAdminStationRepository>((ref) {
  return AdminStationRepository(apiClient: ref.watch(apiClientProvider));
});

final adminScheduleRepositoryProvider =
    Provider<IAdminScheduleRepository>((ref) {
  return AdminScheduleRepository(apiClient: ref.watch(apiClientProvider));
});

final adminDashboardRepositoryProvider =
    Provider<IAdminDashboardRepository>((ref) {
  return AdminDashboardRepository(
    apiClient: ref.watch(apiClientProvider),
    songRepo: ref.watch(adminSongRepositoryProvider),
    stationRepo: ref.watch(adminStationRepositoryProvider),
    scheduleRepo: ref.watch(adminScheduleRepositoryProvider),
  );
});

// --- Dashboard Providers ---

final adminDashboardStatsProvider =
    FutureProvider<AdminDashboardStats>((ref) async {
  final repo = ref.watch(adminDashboardRepositoryProvider);
  return repo.getDashboardStats();
});

// --- Songs Management Notifiers & Providers ---

class AdminSongSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

final adminSongSearchProvider =
    NotifierProvider<AdminSongSearchNotifier, String>(
  AdminSongSearchNotifier.new,
);

class AdminSongActiveFilterNotifier extends Notifier<bool?> {
  @override
  bool? build() => null; // null = all, true = active, false = archived
  void setFilter(bool? active) => state = active;
}

final adminSongActiveFilterProvider =
    NotifierProvider<AdminSongActiveFilterNotifier, bool?>(
  AdminSongActiveFilterNotifier.new,
);

final adminSongsListProvider = FutureProvider<List<AdminSong>>((ref) async {
  final repo = ref.watch(adminSongRepositoryProvider);
  final search = ref.watch(adminSongSearchProvider);
  final activeOnly = ref.watch(adminSongActiveFilterProvider);

  return repo.getSongs(
    search: search.isNotEmpty ? search : null,
    activeOnly: activeOnly,
    limit: 100,
  );
});

final adminSongStatsProvider = FutureProvider<AdminSongStats>((ref) async {
  final repo = ref.watch(adminSongRepositoryProvider);
  return repo.getSongStats();
});

// --- Station Management Providers ---

final adminStationsListProvider = FutureProvider<List<Station>>((ref) async {
  final repo = ref.watch(adminStationRepositoryProvider);
  return repo.getStations(all: true);
});

// --- Schedule Management Providers ---

class AdminScheduleStationFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void selectStation(int? id) => state = id;
}

final adminScheduleStationFilterProvider =
    NotifierProvider<AdminScheduleStationFilterNotifier, int?>(
  AdminScheduleStationFilterNotifier.new,
);

class AdminScheduleStatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null; // null = all, 'published', 'draft'
  void setStatus(String? status) => state = status;
}

final adminScheduleStatusFilterProvider =
    NotifierProvider<AdminScheduleStatusFilterNotifier, String?>(
  AdminScheduleStatusFilterNotifier.new,
);

final adminSchedulesListProvider =
    FutureProvider<List<AdminSchedule>>((ref) async {
  final repo = ref.watch(adminScheduleRepositoryProvider);
  final stationId = ref.watch(adminScheduleStationFilterProvider);
  final status = ref.watch(adminScheduleStatusFilterProvider);

  return repo.getSchedules(
    stationId: stationId,
    status: status,
  );
});

final schedulePlaylistProvider =
    FutureProvider.family<List<SchedulePlaylistTrack>, int>(
        (ref, scheduleId) async {
  final repo = ref.watch(adminScheduleRepositoryProvider);
  return repo.getPlaylistTracks(scheduleId);
});
