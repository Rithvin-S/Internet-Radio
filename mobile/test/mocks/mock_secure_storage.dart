import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pulsecast/core/storage/secure_storage_service.dart';

/// In-memory implementation of SecureStorageService for reliable, platform-independent testing
class MockSecureStorageService extends SecureStorageService {
  final Map<String, String> _data = {};

  MockSecureStorageService() : super(const FlutterSecureStorage());

  @override
  Future<void> saveToken(String token) async {
    _data['pulsecast_jwt_token'] = token;
  }

  @override
  Future<String?> getToken() async {
    return _data['pulsecast_jwt_token'];
  }

  @override
  Future<void> deleteToken() async {
    _data.remove('pulsecast_jwt_token');
  }

  @override
  Future<void> saveUser(Map<String, dynamic> userMap) async {
    _data['pulsecast_cached_user'] = userMap.toString();
  }

  @override
  Future<Map<String, dynamic>?> getUser() async {
    // Return null or parse if needed for tests
    return null;
  }

  @override
  Future<void> deleteUser() async {
    _data.remove('pulsecast_cached_user');
  }

  @override
  Future<void> clearAuth() async {
    _data.clear();
  }

  bool get hasToken => _data.containsKey('pulsecast_jwt_token');
}

