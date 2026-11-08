// Renders the component gallery in every theme to PNG for visual review.
// Not part of the normal suite: run with
//   flutter test test/visual --dart-define=VISUAL_SNAPSHOTS=true
// Output: build/visual/design_system/<theme>_<mode>.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/theme_registry.dart';

import '../core/widgets/component_gallery.dart';

const _enabled = bool.fromEnvironment('VISUAL_SNAPSHOTS');

Future<void> loadSnapshotFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  const dir = 'assets/fonts';
  for (final family in [
    'Nunito',
    'PlayfairDisplay',
    'CormorantGaramond',
    'Lora',
    'DancingScript',
    'Quicksand',
  ]) {
    await load(family, ['$dir/$family.ttf']);
  }
  await load('CourierPrime', [
    '$dir/CourierPrime-Regular.ttf',
    '$dir/CourierPrime-Bold.ttf',
  ]);

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    await load('MaterialIcons', [
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  }
}

void main() {
  testWidgets('design system snapshots', skip: !_enabled, (tester) async {
    await tester.runAsync(loadSnapshotFonts);
    const size = Size(390, 1100);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;

    final out = Directory('build/visual/design_system')
      ..createSync(recursive: true);
    final key = GlobalKey();

    for (final theme in ThemeRegistry.all) {
      final modes =
          theme.supportsDark && theme.light.brightness != theme.dark!.brightness
          ? Brightness.values
          : [theme.light.brightness];
      for (final brightness in modes) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(theme, brightness),
              home: Scaffold(
                appBar: AppBar(title: Text(theme.name)),
                body: const ComponentGallery(compact: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${theme.key}_${brightness.name}.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    }
    tester.view.reset();
  });
}
