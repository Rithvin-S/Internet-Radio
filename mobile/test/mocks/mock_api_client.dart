import 'package:dio/dio.dart';
import 'package:pulsecast/core/network/api_client.dart';
import 'package:pulsecast/core/network/api_exception.dart';
import 'mock_secure_storage.dart';

typedef GetRequestHandler = Future<Response<dynamic>> Function(
  String path, {
  Map<String, dynamic>? queryParameters,
  Options? options,
});

typedef PostRequestHandler = Future<Response<dynamic>> Function(
  String path, {
  dynamic data,
  Map<String, dynamic>? queryParameters,
  Options? options,
});

/// Mock ApiClient that doesn't make real network calls
class MockApiClient extends ApiClient {
  GetRequestHandler? onGet;
  PostRequestHandler? onPost;
  PostRequestHandler? onPut;
  PostRequestHandler? onDelete;

  MockApiClient({
    MockSecureStorageService? storageService,
  }) : super(
          storageService: storageService ?? MockSecureStorageService(),
          customDio: Dio(),
        );

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (onGet != null) {
      final res = await onGet!(path, queryParameters: queryParameters, options: options);
      return res as Response<T>;
    }
    throw ApiException(message: 'Unhandled GET to $path');
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (onPost != null) {
      final res = await onPost!(path, data: data, queryParameters: queryParameters, options: options);
      return res as Response<T>;
    }
    throw ApiException(message: 'Unhandled POST to $path');
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (onPut != null) {
      final res = await onPut!(path, data: data, queryParameters: queryParameters, options: options);
      return res as Response<T>;
    }
    throw ApiException(message: 'Unhandled PUT to $path');
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (onDelete != null) {
      final res = await onDelete!(path, data: data, queryParameters: queryParameters, options: options);
      return res as Response<T>;
    }
    throw ApiException(message: 'Unhandled DELETE to $path');
  }

  PostRequestHandler? onPatch;

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (onPatch != null) {
      final res = await onPatch!(path, data: data, queryParameters: queryParameters, options: options);
      return res as Response<T>;
    }
    throw ApiException(message: 'Unhandled PATCH to $path');
  }
}
