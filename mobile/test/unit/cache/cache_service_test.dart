import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulsecast/core/cache/cache_policy.dart';
import 'package:pulsecast/core/cache/cache_service.dart';

void main() {
  group('CacheService Unit Tests', () {
    late SharedPreferences prefs;
    late CacheService cacheService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      cacheService = CacheService(prefs);
    });

    test('setJson stores envelope and getJson retrieves payload', () async {
      final data = {'name': 'PulseCast', 'streams': 3};
      final ok = await cacheService.setJson(
        'test_key',
        data,
        ttl: const Duration(hours: 1),
      );

      expect(ok, isTrue);
      final retrieved = cacheService.getJson('test_key');
      expect(retrieved, isNotNull);
      expect(retrieved['name'], equals('PulseCast'));
      expect(retrieved['streams'], equals(3));
    });

    test('isFresh returns true for non-expired cache and false after TTL', () async {
      // 1. Valid TTL
      await cacheService.setJson(
        'fresh_key',
        {'status': 'ok'},
        ttl: const Duration(hours: 2),
      );
      expect(cacheService.isFresh('fresh_key'), isTrue);

      // 2. Expired TTL (negative duration)
      await cacheService.setJson(
        'expired_key',
        {'status': 'stale'},
        ttl: const Duration(seconds: -10),
      );
      expect(cacheService.isFresh('expired_key'), isFalse);

      // allowExpired: false returns null
      expect(cacheService.getJson('expired_key', allowExpired: false), isNull);

      // allowExpired: true returns stale data for offline fallback
      final stale = cacheService.getJson('expired_key', allowExpired: true);
      expect(stale, isNotNull);
      expect(stale['status'], equals('stale'));
    });

    test('clearNonEssential flushes catalog cache while strictly preserving user preferences & favorites', () async {
      // Setup non-essential catalog entries
      await cacheService.setJson(
        CachePolicy.keyStationsList,
        [{'id': 1, 'name': 'Radio 1'}],
      );
      await cacheService.setJson(
        CachePolicy.keyListenerTracks,
        [{'id': 10, 'title': 'Song 1'}],
      );
      await cacheService.setJson(
        '${CachePolicy.keyStationPrefix}1',
        {'id': 1, 'name': 'Radio 1'},
      );

      // Setup essential user preference & favorite entries
      await cacheService.setJson(
        CachePolicy.keyUserPreferences,
        {'autoplay': true},
      );
      await cacheService.setJson(
        '${CachePolicy.keyFavoritesStationsPrefix}user_123',
        [1, 2],
      );

      // Perform non-essential clear
      final clearedCount = await cacheService.clearNonEssential();
      expect(clearedCount, equals(3));

      // Verify non-essential are gone
      expect(cacheService.getJson(CachePolicy.keyStationsList), isNull);
      expect(cacheService.getJson(CachePolicy.keyListenerTracks), isNull);
      expect(cacheService.getJson('${CachePolicy.keyStationPrefix}1'), isNull);

      // Verify user settings & favorites are preserved
      expect(cacheService.getJson(CachePolicy.keyUserPreferences), isNotNull);
      expect(
        cacheService.getJson('${CachePolicy.keyFavoritesStationsPrefix}user_123'),
        isNotNull,
      );
    });

    test('getEstimatedCacheSizeBytes computes storage size', () async {
      await cacheService.setJson(
        CachePolicy.keyStationsList,
        [{'id': 1, 'name': 'Nightwave Plaza'}],
      );
      final bytes = cacheService.getEstimatedCacheSizeBytes();
      expect(bytes, greaterThan(0));
    });
  });
}

