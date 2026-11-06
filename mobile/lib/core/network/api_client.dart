import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import '../storage/secure_storage_service.dart';

/// Centralized Dio API Client for PulseCast
class ApiClient {
  final Dio _dio;

  ApiClient({
    required SecureStorageService storageService,
    String? baseUrl,
    void Function()? onUnauthorized,
    Dio? customDio,
  }) : _dio = customDio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
                connectTimeout: Duration(milliseconds: AppConfig.connectTimeout),
                receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeout),
                headers: {
                  'User-Agent': AppConfig.userAgent,
                },
                responseType: ResponseType.json,
              ),
            ) {
    if (customDio == null) {
      _dio.interceptors.add(
        AuthInterceptor(
          storageService: storageService,
          onUnauthorized: onUnauthorized,
        ),
      );
    }
  }

  Dio get dio => _dio;

  /// Performs a GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Performs a POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Performs a PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Performs a DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Performs a PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

