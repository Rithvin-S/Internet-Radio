import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';

/// Interceptor that attaches the JWT Bearer token to outgoing HTTP requests
/// and monitors 401 Unauthorized responses for session expiration.
///
/// Security: Does NOT log tokens, passwords, or Authorization headers.
class AuthInterceptor extends Interceptor {
  final SecureStorageService _storageService;
  final void Function()? _onUnauthorized;

  AuthInterceptor({
    required SecureStorageService storageService,
    void Function()? onUnauthorized,
  })  : _storageService = storageService,
        _onUnauthorized = onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Standard JSON headers
    options.headers['Accept'] = 'application/json';
    if (options.data != null && options.headers['Content-Type'] == null) {
      options.headers['Content-Type'] = 'application/json';
    }

    // Attach JWT if not already manually set
    if (!options.headers.containsKey('Authorization')) {
      final token = await _storageService.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      final path = err.requestOptions.path;
      // Don't trigger session expired if the failed request was a login/register attempt
      final isAuthEndpoint =
          path.contains('/api/auth/login') || path.contains('/api/auth/register');
      if (!isAuthEndpoint) {
        _onUnauthorized?.call();
      }
    }
    return handler.next(err);
  }
}

