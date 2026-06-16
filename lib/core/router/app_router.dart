import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/route_constants.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/presentation/guards/auth_guard.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/barber/presentation/screens/barber_home_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: RouteConstants.splash,
    redirect: (context, state) => authGuard(ref, state),
    routes: [
      GoRoute(
        path: RouteConstants.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteConstants.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteConstants.barberHome,
        builder: (context, state) => const BarberHomeScreen(),
      ),
      GoRoute(
        path: RouteConstants.adminHome,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );

  ref.listen(authProvider, (prev, next) => router.refresh());

  return router;
});
