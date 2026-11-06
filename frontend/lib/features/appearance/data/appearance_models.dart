import 'package:flutter/foundation.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/theme/theme_registry.dart';

/// The couple's shared theme as stored by the server (`GET /couple/theme`).
@immutable
class CoupleThemeSettings {
  const CoupleThemeSettings({
    required this.themeKey,
    required this.customization,
    required this.version,
    this.updatedBy,
    this.updatedAt,
  });

  /// Before the couple has chosen anything (server version 0).
  static const initial = CoupleThemeSettings(
    themeKey: ThemeRegistry.defaultKey,
    customization: ThemeCustomization.defaults,
    version: 0,
  );

  final String themeKey;
  final ThemeCustomization customization;

  /// Optimistic-lock version; every write sends the version it was based on.
  final int version;
  final int? updatedBy;
  final DateTime? updatedAt;

  factory CoupleThemeSettings.fromJson(Map<String, dynamic> json) => CoupleThemeSettings(
        themeKey: json['theme_key'] as String? ?? ThemeRegistry.defaultKey,
        customization: ThemeCustomization.fromJson(
          json['customization'] is Map ? Map<String, dynamic>.from(json['customization'] as Map) : null,
        ),
        version: (json['version'] as num?)?.toInt() ?? 0,
        updatedBy: (json['updated_by'] as num?)?.toInt(),
        updatedAt: json['updated_at'] == null ? null : DateTime.tryParse(json['updated_at'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'theme_key': themeKey,
        'customization': customization.toJson(),
        'version': version,
        'updated_by': updatedBy,
        'updated_at': updatedAt?.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is CoupleThemeSettings &&
      other.themeKey == themeKey &&
      other.customization == customization &&
      other.version == version &&
      other.updatedBy == updatedBy;

  @override
  int get hashCode => Object.hash(themeKey, customization, version, updatedBy);
}

/// What the server currently offers (`GET /appearance/catalog`). Metadata only.
@immutable
class AppearanceCatalog {
  const AppearanceCatalog({required this.themes, required this.photoBoothTemplates});

  final List<CatalogItem> themes;
  final List<CatalogItem> photoBoothTemplates;

  factory AppearanceCatalog.fromJson(Map<String, dynamic> json) {
    List<CatalogItem> items(Object? list) => [
          for (final item in (list as List? ?? const []))
            CatalogItem.fromJson(Map<String, dynamic>.from(item as Map)),
        ];

    return AppearanceCatalog(themes: items(json['themes']), photoBoothTemplates: items(json['photo_booth_templates']));
  }

  Map<String, dynamic> toJson() => {
        'themes': [for (final t in themes) t.toJson()],
        'photo_booth_templates': [for (final t in photoBoothTemplates) t.toJson()],
      };
}

@immutable
class CatalogItem {
  const CatalogItem({required this.key, required this.name, required this.version, this.isPremium = false});

  final String key;
  final String name;
  final int version;
  final bool isPremium;

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
        key: json['key'] as String,
        name: json['name'] as String? ?? json['key'] as String,
        version: (json['version'] as num?)?.toInt() ?? 1,
        isPremium: json['is_premium'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'key': key, 'name': name, 'version': version, 'is_premium': isPremium};
}

/// The partner changed the theme since this device last read it.
class ThemeConflictException implements Exception {
  const ThemeConflictException(this.current);

  final CoupleThemeSettings current;
}
