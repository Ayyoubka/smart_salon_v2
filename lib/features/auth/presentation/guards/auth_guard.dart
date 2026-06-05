import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../shared/enums/user_role.dart';
import '../../domain/models/auth_state.dart';
import '../providers/auth_provider.dart';

String? authGuard(Ref ref, GoRouterState routerState) {
  final location = routerState.matchedLocation;
  final authState = ref.read(authProvider);

  return authState.when(
    loading: () => location == RouteConstants.splash ? null : RouteConstants.splash,
    error: (e, _) => RouteConstants.login,
    data: (state) => switch (state) {
      AuthLoading() => location == RouteConstants.splash ? null : RouteConstants.splash,
      AuthUnauthenticated() => _onUnauthenticated(location),
      AuthAuthenticated(:final role) => _onAuthenticated(location, role),
    },
  );
}

String? _onUnauthenticated(String location) {
  if (location == RouteConstants.login) return null;
  return RouteConstants.login;
}

String? _onAuthenticated(String location, UserRole role) {
  final isAuthRoute = location == RouteConstants.login || location == RouteConstants.splash;
  if (!isAuthRoute) return null;

  return switch (role) {
    UserRole.barber => RouteConstants.barberHome,
    UserRole.admin => RouteConstants.adminHome,
  };
}
