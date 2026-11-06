import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/core/cache/cache_providers.dart';
import '../../data/settings_repository.dart';
import '../../domain/models/user_settings.dart';

/// Provider for SettingsRepository
final settingsRepositoryProvider = Provider<ISettingsRepository>((ref) {
  final cacheService = ref.watch(cacheServiceProvider);
  return SettingsRepository(cacheService: cacheService);
});

/// Reactive Notifier managing UserSettings
class UserSettingsNotifier extends Notifier<UserSettings> {
  late final ISettingsRepository _repository;

  @override
  UserSettings build() {
    _repository = ref.watch(settingsRepositoryProvider);
    return _repository.loadSettings();
  }

  Future<void> setDefaultStation(int? stationId) async {
    final updated = stationId == null
        ? state.copyWith(clearDefaultStation: true)
        : state.copyWith(defaultStationId: stationId);
    state = updated;
    await _repository.saveSettings(updated);
  }

  Future<void> setAutoplay(bool enabled) async {
    final updated = state.copyWith(autoplayOnLaunch: enabled);
    state = updated;
    await _repository.saveSettings(updated);
  }

  Future<void> setStationSort(StationSort sort) async {
    final updated = state.copyWith(stationSort: sort);
    state = updated;
    await _repository.saveSettings(updated);
  }

  Future<void> setPreferredLibraryFilter(String filter) async {
    final updated = state.copyWith(preferredLibraryFilter: filter);
    state = updated;
    await _repository.saveSettings(updated);
  }

  Future<void> setDataSaver(bool enabled) async {
    final updated = state.copyWith(dataSaverMode: enabled);
    state = updated;
    await _repository.saveSettings(updated);
  }

  Future<void> resetToDefaults() async {
    await _repository.resetDefaults();
    state = const UserSettings();
  }

  Future<int> clearNonEssentialCache() async {
    final cacheService = ref.read(cacheServiceProvider);
    final count = await cacheService.clearNonEssential();
    ref.invalidate(cacheStatsProvider);
    return count;
  }
}

final userSettingsProvider =
    NotifierProvider<UserSettingsNotifier, UserSettings>(
  UserSettingsNotifier.new,
);

