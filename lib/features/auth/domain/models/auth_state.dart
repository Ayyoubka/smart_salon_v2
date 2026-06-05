import '../../../../shared/enums/user_role.dart';

sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final String uid;
  final UserRole role;
  const AuthAuthenticated({required this.uid, required this.role});
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}
