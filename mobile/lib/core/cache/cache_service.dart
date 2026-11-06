import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_policy.dart';

/// Service providing persistent offline metadata caching using SharedPreferences
class CacheService {
  final SharedPreferences? _prefs;

  CacheService([this._prefs]);

  /// Caches arbitrary JSON-encodable data with an optional TTL
  Future<bool> setJson(String key, dynamic data, {Duration? ttl}) async {
    if (_prefs == null) return false;
    try {
      final envelope = {
        'cached_at': DateTime.now().toIso8601String(),
        'ttl_seconds': ttl?.inSeconds,
        'payload': data,
      };
      return await _prefs.setString(key, jsonEncode(envelope));
    } catch (_) {
      return false;
    }
  }

  /// Retrieves cached payload.
  /// If [allowExpired] is true, returns stale data when offline rather than null.
  dynamic getJson(String key, {bool allowExpired = true}) {
    if (_prefs == null) return null;
    try {
      final raw = _prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final cachedAtStr = decoded['cached_at'] as String?;
      final ttlSeconds = decoded['ttl_seconds'] as int?;
      final payload = decoded['payload'];

      if (cachedAtStr == null) return payload;

      final cachedAt = DateTime.tryParse(cachedAtStr);
      if (cachedAt != null && ttlSeconds != null) {
        final expiresAt = cachedAt.add(Duration(seconds: ttlSeconds));
        final isExpired = DateTime.now().isAfter(expiresAt);
        if (isExpired && !allowExpired) {
          return null;
        }
      }

      return payload;
    } catch (_) {
      return null;
    }
  }

  /// Checks if the cached key exists and has not expired
  bool isFresh(String key) {
    if (_prefs == null) return false;
    try {
      final raw = _prefs.getString(key);
      if (raw == null || raw.isEmpty) return false;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return false;

      final cachedAtStr = decoded['cached_at'] as String?;
      final ttlSeconds = decoded['ttl_seconds'] as int?;
      if (cachedAtStr == null || ttlSeconds == null) return true;

      final cachedAt = DateTime.tryParse(cachedAtStr);
      if (cachedAt == null) return false;

      final expiresAt = cachedAt.add(Duration(seconds: ttlSeconds));
      return DateTime.now().isBefore(expiresAt);
    } catch (_) {
      return false;
    }
  }

  /// Gets timestamp when the key was cached
  DateTime? getLastCachedTime(String key) {
    if (_prefs == null) return null;
    try {
      final raw = _prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final cachedAtStr = decoded['cached_at'] as String?;
      return cachedAtStr != null ? DateTime.tryParse(cachedAtStr) : null;
    } catch (_) {
      return null;
    }
  }

  /// Removes a single cached key
  Future<bool> remove(String key) async {
    if (_prefs == null) return true;
    return await _prefs.remove(key);
  }

  /// Checks whether a key exists in cache
  bool has(String key) => _prefs?.containsKey(key) ?? false;

  /// Clears only non-essential cached metadata (catalogs, tracks, schedules),
  /// strictly preserving user settings, local favorites, and auth data.
  Future<int> clearNonEssential() async {
    if (_prefs == null) return 0;
    int clearedCount = 0;
    final allKeys = _prefs.getKeys();

    for (final key in allKeys) {
      final isNonEssential = CachePolicy.nonEssentialCacheKeys.contains(key) ||
          key.startsWith(CachePolicy.keyStationPrefix);

      if (isNonEssential) {
        await _prefs.remove(key);
        clearedCount++;
      }
    }

    return clearedCount;
  }

  /// Computes estimated total cached storage bytes across all non-essential entries
  int getEstimatedCacheSizeBytes() {
    if (_prefs == null) return 0;
    int totalBytes = 0;
    final allKeys = _prefs.getKeys();

    for (final key in allKeys) {
      if (CachePolicy.nonEssentialCacheKeys.contains(key) ||
          key.startsWith(CachePolicy.keyStationPrefix)) {
        final val = _prefs.getString(key);
        if (val != null) {
          totalBytes += val.length;
        }
      }
    }

    return totalBytes;
  }
}
