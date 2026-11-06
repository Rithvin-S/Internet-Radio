import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/core/network/api_exception.dart';
import 'package:pulsecast/features/auth/data/auth_repository.dart';
import 'package:pulsecast/features/auth/domain/models/auth_response.dart';
import 'package:pulsecast/features/auth/domain/models/user.dart';
import 'package:pulsecast/features/auth/domain/models/user_role.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_providers.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_state.dart';

class StubAuthRepository implements IAuthRepository {
  bool shouldSucceed = true;
  User? mockUser;
  ApiException? errorToThrow;

  StubAuthRepository({this.mockUser});

  @override
  Future<AuthResponse> login({required String email, required String password}) async {
    if (errorToThrow != null) throw errorToThrow!;
    return AuthResponse(
      success: true,
      message: 'OK',
      token: 'jwt_token_123',
      user: mockUser,
    );
  }

  @override
  Future<AuthResponse> register({required String name, required String email, required String password}) async {
    if (errorToThrow != null) throw errorToThrow!;
    return AuthResponse(
      success: true,
      message: 'OK',
      token: 'jwt_token_123',
      user: mockUser,
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<User?> getMe() async => mockUser;

  @override
  Future<User?> restoreSession() async => mockUser;
}

void main() {
  group('AuthNotifier State Machine Tests', () {
    test('Successful login transitions state to authenticated with User', () async {
      final user = User(
        id: 2,
        name: 'Alex Rivera',
        email: 'listener@pulsecast.com',
        role: UserRole.listener,
      );

      final repo = StubAuthRepository(mockUser: user);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final notifier = container.read(authNotifierProvider.notifier);
      final success = await notifier.login(
        email: 'listener@pulsecast.com',
        password: 'ValidPass123!',
      );

      expect(success, isTrue);
      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, user);
      expect(state.isAuthenticated, isTrue);
    });

    test('Failed login transitions state to error with message', () async {
      final repo = StubAuthRepository();
      repo.errorToThrow = ApiException(
        message: 'Invalid email or password.',
        statusCode: 401,
      );

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final notifier = container.read(authNotifierProvider.notifier);
      final success = await notifier.login(
        email: 'bad@pulsecast.com',
        password: 'wrong',
      );

      expect(success, isFalse);
      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, 'Invalid email or password.');
      expect(state.isAuthenticated, isFalse);
    });

    test('Logout transitions state to unauthenticated', () async {
      final user = User(
        id: 1,
        name: 'Admin',
        email: 'admin@pulsecast.com',
        role: UserRole.admin,
      );

      final repo = StubAuthRepository(mockUser: user);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login(email: 'admin@pulsecast.com', password: 'pass');
      expect(container.read(authNotifierProvider).isAuthenticated, isTrue);

      await notifier.logout();
      expect(container.read(authNotifierProvider).status, AuthStatus.unauthenticated);
      expect(container.read(authNotifierProvider).user, isNull);
    });

    test('handleSessionExpired sets unauthenticated with sessionExpired true', () {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(StubAuthRepository()),
        ],
      );

      final notifier = container.read(authNotifierProvider.notifier);
      notifier.handleSessionExpired();

      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.sessionExpired, isTrue);
    });
  });
}

