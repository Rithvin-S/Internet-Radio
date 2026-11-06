/// User roles supported by the PulseCast backend RBAC
enum UserRole {
  listener,
  admin;

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.listener;
    switch (role.toLowerCase().trim()) {
      case 'admin':
        return UserRole.admin;
      case 'listener':
      default:
        return UserRole.listener;
    }
  }

  String toRoleString() {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.listener:
        return 'listener';
    }
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isListener => this == UserRole.listener;
}

