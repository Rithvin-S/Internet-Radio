import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage_service.dart';
import 'api_client.dart';

/// Provider for Flutter Secure Storage wrapper
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Callback notifier for session expired events
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void notifyExpired() {
    state++;
  }
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiredNotifier, int>(SessionExpiredNotifier.new);

/// Provider for centralized Dio ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return ApiClient(
    storageService: storage,
    onUnauthorized: () {
      ref.read(sessionExpiredProvider.notifier).notifyExpired();
    },
  );
});

