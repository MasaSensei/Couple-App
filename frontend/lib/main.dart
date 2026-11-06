import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/font_licenses.dart';
import 'features/appearance/data/appearance_local_store.dart';
import 'features/appearance/providers/appearance_controller.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/providers/auth_state.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();

  // Read before the first frame so the app opens in the couple's theme
  // (no flash of the default theme on every start).
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [appearanceLocalStoreProvider.overrideWithValue(AppearanceLocalStore(prefs))],
      child: const CoupleApp(),
    ),
  );
}

class CoupleApp extends ConsumerStatefulWidget {
  const CoupleApp({super.key});

  @override
  ConsumerState<CoupleApp> createState() => _CoupleAppState();
}

class _CoupleAppState extends ConsumerState<CoupleApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();

    // There is no push channel yet: pick up the partner's theme changes
    // whenever the app comes back to the foreground.
    _lifecycle = AppLifecycleListener(onResume: () {
      if (ref.read(authNotifierProvider).status == AuthStatus.authenticated) {
        ref.read(appearanceControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(appearanceControllerProvider.select((state) => state.themeMode));

    // MaterialApp animates between ThemeData values (AnimatedTheme), and the
    // token extension lerps, so applying a theme never rebuilds the routes.
    return MaterialApp.router(
      title: 'Couples App',
      debugShowCheckedModeBanner: false,
      theme: ref.watch(appThemeDataProvider(Brightness.light)),
      darkTheme: ref.watch(appThemeDataProvider(Brightness.dark)),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
