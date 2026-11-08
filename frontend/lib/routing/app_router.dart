import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_providers.dart';
import '../features/auth/providers/auth_state.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/home/presentation/date_list_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/profile/presentation/me_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/memories/presentation/screens/memory_list_screen.dart';
import '../features/memories/presentation/screens/memory_form_screen.dart';
import '../features/device/data/presentation/screens/device_management_screen.dart';
import 'app_shell.dart';

/// Root navigator: full-screen flows (forms, Photo Booth, viewer) push here
/// so the bottom navigation is hidden while they are open.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Tab order of the bottom navigation.
abstract final class AppTabs {
  static const home = '/home';
  static const dates = '/dates';
  static const memories = '/memories';
  static const me = '/me';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
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

      // Each tab keeps its own navigation stack (detail screens pushed from
      // a tab stay under the bottom bar; switching tabs keeps scroll state).
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTabs.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTabs.dates,
                builder: (context, state) => const DateListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTabs.memories,
                builder: (context, state) => const MemoryListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTabs.me,
                builder: (context, state) => const MeScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/memories/create',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MemoryFormScreen(),
      ),
      GoRoute(
        path: '/devices',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DeviceManagementScreen(),
      ),
    ],
  );

  ref.listen<AuthState>(authNotifierProvider, (_, next) {
    if (next.status == AuthStatus.authenticated) {
      router.go(AppTabs.home);
    }

    if (next.status == AuthStatus.unauthenticated) {
      router.go('/login');
    }
  });

  ref.onDispose(router.dispose);

  return router;
});
