import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/theme/theme_registry.dart';

/// The backend validates couples' choices against
/// backend/database/data/appearance_catalog.json; the app draws them from
/// ThemeRegistry. If the two drift apart, couples could save settings the app
/// cannot draw (or be refused ones it can). This test keeps them identical.
void main() {
  final catalog = jsonDecode(
    File('../backend/database/data/appearance_catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test(
    'every catalog theme exists in the app with the same version and presets',
    () {
      final themes = (catalog['themes'] as List).cast<Map<String, dynamic>>();

      expect(themes.map((t) => t['key']), ThemeRegistry.all.map((t) => t.key));

      for (final entry in themes) {
        final theme = ThemeRegistry.byKey(entry['key'] as String);
        final options = entry['options'] as Map<String, dynamic>;

        expect(entry['version'], theme.version, reason: theme.key);
        expect(
          options['accents'],
          theme.accentPresets.map((p) => p.key).toList(),
          reason: theme.key,
        );
        expect(
          options['backgrounds'],
          theme.backgroundPresets.map((p) => p.key).toList(),
          reason: theme.key,
        );
        expect(
          options['fonts'],
          theme.fontPresets.map((p) => p.key).toList(),
          reason: theme.key,
        );
        expect(entry['is_default'], theme.key == ThemeRegistry.defaultKey);
      }
    },
  );

  test('layout styles match the customization enums', () {
    final customization = catalog['customization'] as Map<String, dynamic>;

    expect(
      customization['couple_space_styles'],
      CoupleSpaceStyle.values.map((v) => v.name).toList(),
    );
    expect(
      customization['memory_styles'],
      MemoryStyle.values.map((v) => v.name).toList(),
    );
  });
}
