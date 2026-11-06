import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../data/auth_repository.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

class AuthNotifier extends Notifier<AuthState> {
  late final IAuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);

    // Listen for 401 unauthorized session-expired events
    ref.listen(sessionExpiredProvider, (previous, next) {
      if (previous != null && next > previous) {
        handleSessionExpired();
      }
    });

    // Auto-restore session from secure storage on startup
    Future.microtask(() => restoreSession());

    return const AuthState.initial();
  }

  /// Restores session on app startup
  Future<void> restoreSession() async {
    state = const AuthState.loading();
    try {
      final user = await _repository.restoreSession();
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      state = const AuthState.unauthenticated();
    }
  }

  /// Authenticates user with email and password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = AuthState.loading(currentUser: state.user);
    try {
      final response = await _repository.login(
        email: email,
        password: password,
      );

      if (response.user != null) {
        state = AuthState.authenticated(response.user!);
        return true;
      } else {
        state = const AuthState.error(
          message: 'Sign in completed but user profile was not returned.',
        );
        return false;
      }
    } on ApiException catch (e) {
      state = AuthState.error(
        message: e.message,
        errors: e.errors,
      );
      return false;
    } catch (e) {
      state = AuthState.error(
        message: 'An unexpected error occurred: ${e.toString()}',
      );
      return false;
    }
  }

  /// Registers a new listener account
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = AuthState.loading(currentUser: state.user);
    try {
      final response = await _repository.register(
        name: name,
        email: email,
        password: password,
      );

      if (response.user != null) {
        state = AuthState.authenticated(response.user!);
        return true;
      } else {
        state = const AuthState.error(
          message: 'Registration completed but user profile was not returned.',
        );
        return false;
      }
    } on ApiException catch (e) {
      state = AuthState.error(
        message: e.message,
        errors: e.errors,
      );
      return false;
    } catch (e) {
      state = AuthState.error(
        message: 'An unexpected error occurred: ${e.toString()}',
      );
      return false;
    }
  }

  /// Logs out the user and clears secure storage
  Future<void> logout() async {
    state = const AuthState.loading();
    try {
      await _repository.logout();
    } finally {
      state = const AuthState.unauthenticated();
    }
  }

  /// Triggered when the backend returns 401 on an authenticated endpoint
  void handleSessionExpired() {
    state = const AuthState.unauthenticated(sessionExpired: true);
  }

  /// Clears any active error banner
  void clearError() {
    if (state.status == AuthStatus.error) {
      state = state.user != null
          ? AuthState.authenticated(state.user!)
          : const AuthState.unauthenticated();
    }
  }
}

