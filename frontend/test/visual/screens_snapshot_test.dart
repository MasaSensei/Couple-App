// Renders the redesigned main screens with example data in every theme to
// PNG for visual review. Not part of the normal suite:
//   flutter test test/visual --dart-define=VISUAL_SNAPSHOTS=true
// Output: build/visual/screens/<screen>_<theme>_<mode>.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/theme_registry.dart';
import 'package:frontend/features/home/presentation/date_list_screen.dart';
import 'package:frontend/features/home/presentation/home_screen.dart';
import 'package:frontend/features/memories/presentation/screens/memory_list_screen.dart';
import 'package:frontend/features/profile/presentation/me_screen.dart';
import 'package:frontend/routing/app_shell.dart';

import '../support/screen_harness.dart';
import 'design_system_snapshot_test.dart' show loadSnapshotFonts;

const _enabled = bool.fromEnvironment('VISUAL_SNAPSHOTS');

/// Draws the app's bottom navigation under a tab screen, as in the app.
class _WithNav extends StatelessWidget {
  const _WithNav({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      destinations: AppShell.destinations,
    ),
  );
}

void main() {
  testWidgets('screen snapshots', skip: !_enabled, (tester) async {
    await tester.runAsync(loadSnapshotFonts);
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    final out = Directory('build/visual/screens')..createSync(recursive: true);

    final screens = <String, Widget>{
      'home': const _WithNav(index: 0, child: HomeScreen()),
      'dates': const _WithNav(index: 1, child: DateListScreen()),
      'memories': const _WithNav(index: 2, child: MemoryListScreen()),
      'me': const _WithNav(index: 3, child: MeScreen()),
    };

    for (final theme in ThemeRegistry.all) {
      final modes =
          theme.supportsDark && theme.light.brightness != theme.dark!.brightness
          ? Brightness.values
          : [theme.light.brightness];
      for (final brightness in modes) {
        for (final MapEntry(key: name, value: screen) in screens.entries) {
          final key = GlobalKey();
          await pumpScreen(
            tester,
            RepaintBoundary(key: key, child: screen),
            theme: theme,
            brightness: brightness,
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            File('${out.path}/${name}_${theme.key}_${brightness.name}.png')
                .writeAsBytesSync(png!.buffer.asUint8List());
          });
        }
      }
    }
    tester.view.reset();
  });
}
