import '../../domain/models/user.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final List<String> fieldErrors;
  final bool sessionExpired;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.fieldErrors = const [],
    this.sessionExpired = false,
  });

  const AuthState.initial()
      : status = AuthStatus.initial,
        user = null,
        errorMessage = null,
        fieldErrors = const [],
        sessionExpired = false;

  const AuthState.loading({User? currentUser})
      : status = AuthStatus.loading,
        user = currentUser,
        errorMessage = null,
        fieldErrors = const [],
        sessionExpired = false;

  const AuthState.authenticated(User authenticatedUser)
      : status = AuthStatus.authenticated,
        user = authenticatedUser,
        errorMessage = null,
        fieldErrors = const [],
        sessionExpired = false;

  const AuthState.unauthenticated({this.sessionExpired = false})
      : status = AuthStatus.unauthenticated,
        user = null,
        errorMessage = null,
        fieldErrors = const [];

  const AuthState.error({
    required String message,
    List<String> errors = const [],
    User? currentUser,
  })  : status = AuthStatus.error,
        user = currentUser,
        errorMessage = message,
        fieldErrors = errors,
        sessionExpired = false;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  bool get isAdmin => isAuthenticated && user!.isAdmin;

  bool get isListener => isAuthenticated && user!.isListener;

  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    List<String>? fieldErrors,
    bool? sessionExpired,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      sessionExpired: sessionExpired ?? this.sessionExpired,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          user == other.user &&
          errorMessage == other.errorMessage &&
          sessionExpired == other.sessionExpired;

  @override
  int get hashCode =>
      status.hashCode ^
      user.hashCode ^
      errorMessage.hashCode ^
      sessionExpired.hashCode;
}
