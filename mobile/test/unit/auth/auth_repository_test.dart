import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/core/network/api_endpoints.dart';
import 'package:pulsecast/core/network/api_exception.dart';
import 'package:pulsecast/features/auth/data/auth_repository.dart';
import 'package:pulsecast/features/auth/domain/models/user_role.dart';
import '../../mocks/mock_api_client.dart';
import '../../mocks/mock_secure_storage.dart';

void main() {
  group('AuthRepository Unit Tests', () {
    late MockSecureStorageService mockStorage;
    late MockApiClient mockApiClient;
    late AuthRepository repository;

    setUp(() {
      mockStorage = MockSecureStorageService();
      mockApiClient = MockApiClient(storageService: mockStorage);
      repository = AuthRepository(
        apiClient: mockApiClient,
        storageService: mockStorage,
      );
    });

    test('Successful login stores token and returns User profile', () async {
      mockApiClient.onPost = (path, {data, queryParameters, options}) async {
        expect(path, ApiEndpoints.login);
        expect(data['email'], 'listener@pulsecast.com');
        expect(data['password'], 'ValidPass123!');

        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'message': 'Signed in successfully.',
            'token': 'jwt_mock_token_abc123',
            'user': {
              'id': 2,
              'name': 'Alex Rivera',
              'email': 'listener@pulsecast.com',
              'role': 'listener',
              'created_at': '2026-10-29T06:59:57.000Z',
            },
          },
        );
      };

      final result = await repository.login(
        email: 'listener@pulsecast.com',
        password: 'ValidPass123!',
      );

      expect(result.success, isTrue);
      expect(result.token, 'jwt_mock_token_abc123');
      expect(result.user, isNotNull);
      expect(result.user!.name, 'Alex Rivera');
      expect(result.user!.role, UserRole.listener);

      // Verifies Token storage
      final storedToken = await mockStorage.getToken();
      expect(storedToken, 'jwt_mock_token_abc123');
    });

    test('Failed login with invalid credentials throws ApiException and does not store token', () async {
      mockApiClient.onPost = (path, {data, queryParameters, options}) async {
        throw ApiException(
          message: 'Invalid email or password.',
          statusCode: 401,
        );
      };

      expect(
        () => repository.login(
          email: 'wrong@pulsecast.com',
          password: 'BadPassword',
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          401,
        )),
      );

      final storedToken = await mockStorage.getToken();
      expect(storedToken, isNull);
    });

    test('Registration validation error returns ApiException with error details', () async {
      mockApiClient.onPost = (path, {data, queryParameters, options}) async {
        throw ApiException(
          message: 'Validation failed.',
          statusCode: 400,
          errors: ['Password must be at least 6 characters long.'],
        );
      };

      try {
        await repository.register(
          name: 'Jane',
          email: 'jane@example.com',
          password: '123',
        );
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.errors, contains('Password must be at least 6 characters long.'));
      }
    });

    test('Session restoration returns null when no token is present', () async {
      final user = await repository.restoreSession();
      expect(user, isNull);
    });

    test('Session restoration returns verified User when token is valid', () async {
      await mockStorage.saveToken('valid_stored_token');

      mockApiClient.onGet = (path, {queryParameters, options}) async {
        expect(path, ApiEndpoints.me);
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'success': true,
            'user': {
              'id': 1,
              'name': 'Admin User',
              'email': 'admin@pulsecast.com',
              'role': 'admin',
              'created_at': '2026-10-29T06:59:57.000Z',
            },
          },
        );
      };

      final user = await repository.restoreSession();
      expect(user, isNotNull);
      expect(user!.name, 'Admin User');
      expect(user.isAdmin, isTrue);
    });

    test('Expired session on getMe clears token and returns null', () async {
      await mockStorage.saveToken('expired_jwt_token');

      mockApiClient.onGet = (path, {queryParameters, options}) async {
        throw ApiException(
          message: 'Session has expired. Please sign in again.',
          statusCode: 401,
        );
      };

      final user = await repository.restoreSession();
      expect(user, isNull);

      // Verifies storage was cleaned up on expired session
      final token = await mockStorage.getToken();
      expect(token, isNull);
    });

    test('Logout clears tokens and credentials from secure storage', () async {
      await mockStorage.saveToken('token_to_clear');

      mockApiClient.onPost = (path, {data, queryParameters, options}) async {
        expect(path, ApiEndpoints.logout);
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {'success': true, 'message': 'Signed out successfully.'},
        );
      };

      await repository.logout();

      final storedToken = await mockStorage.getToken();
      expect(storedToken, isNull);
    });
  });
}

