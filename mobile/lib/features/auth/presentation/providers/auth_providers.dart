import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user.dart';
import 'auth_notifier.dart';
import 'auth_state.dart';

/// Provider for the AuthRepository
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    storageService: ref.watch(secureStorageServiceProvider),
  );
});

/// Central Riverpod NotifierProvider for Authentication State
final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Provider exposing the current authenticated User (or null if guest)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authNotifierProvider).user;
});

/// Provider indicating whether the user is currently authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isAuthenticated;
});

/// Provider indicating whether the current user holds the elevated Admin role
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isAdmin;
});

/// Provider indicating whether an auth operation is in progress
final isAuthLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isLoading;
});

