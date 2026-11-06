import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage Service for sensitive credentials and JWT tokens
class SecureStorageService {
  final FlutterSecureStorage _storage;

  static const String _keyToken = 'pulsecast_jwt_token';
  static const String _keyUser = 'pulsecast_cached_user';

  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  /// Saves the JWT authentication token securely
  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _keyToken, value: token);
    } catch (_) {}
  }

  /// Retrieves the stored JWT token, or null if absent
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _keyToken);
    } catch (_) {
      return null;
    }
  }

  /// Deletes the JWT token from secure storage
  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _keyToken);
    } catch (_) {}
  }

  /// Saves cached user profile JSON for offline/fast restoration
  Future<void> saveUser(Map<String, dynamic> userMap) async {
    try {
      await _storage.write(key: _keyUser, value: jsonEncode(userMap));
    } catch (_) {}
  }

  /// Retrieves cached user profile, or null if absent
  Future<Map<String, dynamic>?> getUser() async {
    try {
      final raw = await _storage.read(key: _keyUser);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Deletes cached user profile
  Future<void> deleteUser() async {
    try {
      await _storage.delete(key: _keyUser);
    } catch (_) {}
  }

  /// Clears all stored auth data (token and cached user)
  Future<void> clearAuth() async {
    await deleteToken();
    await deleteUser();
  }
}
