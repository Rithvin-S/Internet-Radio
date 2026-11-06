import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulsecast/core/cache/cache_service.dart';
import 'package:pulsecast/features/settings/data/settings_repository.dart';
import 'package:pulsecast/features/settings/domain/models/user_settings.dart';

void main() {
  group('SettingsRepository Unit Tests', () {
    late SharedPreferences prefs;
    late CacheService cacheService;
    late SettingsRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      cacheService = CacheService(prefs);
      repository = SettingsRepository(cacheService: cacheService);
    });

    test('loadSettings returns initial defaults when no settings are saved', () {
      final settings = repository.loadSettings();

      expect(settings.defaultStationId, isNull);
      expect(settings.autoplayOnLaunch, isTrue);
      expect(settings.stationSort, equals(StationSort.defaultSort));
      expect(settings.preferredLibraryFilter, equals('all'));
      expect(settings.dataSaverMode, isFalse);
    });

    test('saveSettings persists user preferences across restarts', () async {
      const custom = UserSettings(
        defaultStationId: 7,
        autoplayOnLaunch: true,
        stationSort: StationSort.nameAsc,
        preferredLibraryFilter: 'live',
        dataSaverMode: true,
      );

      await repository.saveSettings(custom);

      final reloaded = repository.loadSettings();
      expect(reloaded.defaultStationId, equals(7));
      expect(reloaded.autoplayOnLaunch, isTrue);
      expect(reloaded.stationSort, equals(StationSort.nameAsc));
      expect(reloaded.preferredLibraryFilter, equals('live'));
      expect(reloaded.dataSaverMode, isTrue);
    });

    test('resetDefaults removes saved preferences and restores factory defaults', () async {
      const custom = UserSettings(
        defaultStationId: 1,
        autoplayOnLaunch: true,
      );
      await repository.saveSettings(custom);

      await repository.resetDefaults();
      final restored = repository.loadSettings();

      expect(restored.defaultStationId, isNull);
      expect(restored.autoplayOnLaunch, isTrue);
    });
  });
}

