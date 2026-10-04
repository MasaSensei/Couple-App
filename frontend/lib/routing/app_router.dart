import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_providers.dart';
import '../features/auth/providers/auth_state.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/memories/presentation/screens/memory_list_screen.dart';
import '../features/memories/presentation/screens/memory_form_screen.dart';
import '../features/device/data/presentation/screens/device_management_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/memories',
        builder: (context, state) {
          return const MemoryListScreen();
        },
      ),
      GoRoute(
        path: '/memories/create',
        builder: (context, state) {
          return const MemoryFormScreen();
        },
      ),
      GoRoute(
        path: '/devices',
        builder: (context, state) {
          return const DeviceManagementScreen();
        },
      ),
    ],
  );

  ref.listen<AuthState>(authNotifierProvider, (_, next) {
    if (next.status == AuthStatus.authenticated) {
      router.go('/home');
    }

    if (next.status == AuthStatus.unauthenticated) {
      router.go('/login');
    }
  });

  ref.onDispose(router.dispose);

  return router;
});
