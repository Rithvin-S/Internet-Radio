import 'package:pulsecast/core/cache/cache_policy.dart';
import 'package:pulsecast/core/cache/cache_service.dart';
import '../domain/models/user_settings.dart';

abstract class ISettingsRepository {
  UserSettings loadSettings();
  Future<void> saveSettings(UserSettings settings);
  Future<void> resetDefaults();
}

class SettingsRepository implements ISettingsRepository {
  final CacheService _cacheService;

  SettingsRepository({required CacheService cacheService})
      : _cacheService = cacheService;

  @override
  UserSettings loadSettings() {
    try {
      final json = _cacheService.getJson(
        CachePolicy.keyUserPreferences,
        allowExpired: true,
      );
      if (json is Map<String, dynamic>) {
        return UserSettings.fromJson(json);
      }
      return const UserSettings();
    } catch (_) {
      return const UserSettings();
    }
  }

  @override
  Future<void> saveSettings(UserSettings settings) async {
    await _cacheService.setJson(
      CachePolicy.keyUserPreferences,
      settings.toJson(),
    );
  }

  @override
  Future<void> resetDefaults() async {
    await _cacheService.remove(CachePolicy.keyUserPreferences);
  }
}

