import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_service.dart';

/// Provider for the SharedPreferences instance (overridden in main.dart; defaults to null in tests)
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Provider for the CacheService singleton wrapper
final cacheServiceProvider = Provider<CacheService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CacheService(prefs);
});

/// Provider for real-time estimated cache storage size and stats
final cacheStatsProvider = Provider.autoDispose<Map<String, dynamic>>((ref) {
  final cacheService = ref.watch(cacheServiceProvider);
  final bytes = cacheService.getEstimatedCacheSizeBytes();

  return {
    'bytes': bytes,
    'kb': (bytes / 1024).toStringAsFixed(1),
    'mb': (bytes / (1024 * 1024)).toStringAsFixed(2),
  };
});
