import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appearance/providers/appearance_controller.dart';
import 'photo_booth_screen.dart';

/// Opens Photo Booth full screen (above the bottom navigation). Offline or
/// before the catalog loads: all built-in layouts. Premium layouts outside the
/// couple's plan are not offered.
Future<void> openPhotoBooth(BuildContext context, WidgetRef ref) {
  final catalog = ref.read(appearanceControllerProvider).catalog;
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoBoothScreen(
        availableTemplates: catalog?.photoBoothTemplates
            .where((t) => !t.locked)
            .map((t) => t.key)
            .toSet(),
      ),
    ),
  );
}
