import 'package:dio/dio.dart';

/// Base exception class for all PulseCast API and network errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final List<String> errors;
  final dynamic originalError;

  ApiException({
    required this.message,
    this.statusCode,
    this.errors = const [],
    this.originalError,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isRateLimited => statusCode == 429;

  /// Creates a typed [ApiException] from a [DioException]
  factory ApiException.fromDioError(DioException dioError) {
    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message:
              'Connection timed out. Please check your internet connection.',
          statusCode: null,
          originalError: dioError,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message:
              'Unable to connect to the PulseCast server. Please check your network connection.',
          statusCode: null,
          originalError: dioError,
        );
      case DioExceptionType.badResponse:
        final response = dioError.response;
        final statusCode = response?.statusCode;
        final data = response?.data;

        String message = 'A server error occurred. Please try again.';
        List<String> errors = [];

        if (data is Map<String, dynamic>) {
          if (data['message'] is String && (data['message'] as String).isNotEmpty) {
            message = data['message'];
          }
          if (data['errors'] is List) {
            errors = (data['errors'] as List)
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        }

        if (statusCode == 401 &&
            (message.isEmpty || message == 'A server error occurred. Please try again.')) {
          message = 'Authentication required or session expired.';
        } else if (statusCode == 403) {
          message = data is Map && data['message'] != null
              ? data['message']
              : 'Access denied. Administrator privileges required.';
        } else if (statusCode == 409) {
          message = data is Map && data['message'] != null
              ? data['message']
              : 'An account with this email address already exists.';
        } else if (statusCode == 429) {
          message = 'Too many requests. Please try again in a few moments.';
        }

        return ApiException(
          message: message,
          statusCode: statusCode,
          errors: errors,
          originalError: dioError,
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: 'The request was cancelled.',
          statusCode: null,
          originalError: dioError,
        );
      default:
        return ApiException(
          message: 'An unexpected error occurred. Please try again.',
          statusCode: null,
          originalError: dioError,
        );
    }
  }

  @override
  String toString() {
    if (errors.isNotEmpty) {
      return '$message (${errors.join(', ')})';
    }
    return message;
  }
}

