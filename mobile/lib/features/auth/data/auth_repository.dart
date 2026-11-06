import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/models/auth_response.dart';
import '../domain/models/user.dart';

abstract class IAuthRepository {
  Future<AuthResponse> login({
    required String email,
    required String password,
  });

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<User?> getMe();

  Future<User?> restoreSession();
}

class AuthRepository implements IAuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _storageService;

  AuthRepository({
    required ApiClient apiClient,
    required SecureStorageService storageService,
  })  : _apiClient = apiClient,
        _storageService = storageService;

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final authResponse = AuthResponse.fromJson(data);

    if (authResponse.token != null && authResponse.token!.isNotEmpty) {
      await _storageService.saveToken(authResponse.token!);
    }

    if (authResponse.user != null) {
      await _storageService.saveUser(authResponse.user!.toJson());
    }

    return authResponse;
  }

  @override
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      data: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final authResponse = AuthResponse.fromJson(data);

    if (authResponse.token != null && authResponse.token!.isNotEmpty) {
      await _storageService.saveToken(authResponse.token!);
    }

    if (authResponse.user != null) {
      await _storageService.saveUser(authResponse.user!.toJson());
    }

    return authResponse;
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.post(ApiEndpoints.logout);
    } catch (_) {
      // Best-effort remote logout; always clear local credentials
    } finally {
      await _storageService.clearAuth();
    }
  }

  @override
  Future<User?> getMe() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.me);
      final data = response.data as Map<String, dynamic>;

      if (data['user'] != null && data['user'] is Map<String, dynamic>) {
        final user = User.fromJson(data['user'] as Map<String, dynamic>);
        await _storageService.saveUser(user.toJson());
        return user;
      }
      return null;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _storageService.clearAuth();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<User?> restoreSession() async {
    final token = await _storageService.getToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    // Load cached user profile
    final cachedUserMap = await _storageService.getUser();
    final cachedUser =
        cachedUserMap != null ? User.fromJson(cachedUserMap) : null;

    try {
      // Validate session with live backend
      final liveUser = await getMe();
      return liveUser ?? cachedUser;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // Token was rejected as expired/invalid
        await _storageService.clearAuth();
        return null;
      }
      // If network unreachable, return cached user for offline tolerance
      return cachedUser;
    } catch (_) {
      return cachedUser;
    }
  }
}

