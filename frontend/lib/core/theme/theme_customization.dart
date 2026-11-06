import 'package:flutter/foundation.dart';

/// How the Couple Space home is laid out.
enum CoupleSpaceStyle { classic, cozy, minimal }

/// How memories and their photos are framed.
enum MemoryStyle { soft, polaroid, minimal }

/// A couple's choices on top of a theme. Stored separately from the built-in
/// [ThemeDefinition], as preset *keys*, never raw colors or fonts; anything
/// unknown falls back to the theme default. Empty = the theme's defaults.
@immutable
class ThemeCustomization {
  const ThemeCustomization({
    this.accent,
    this.background,
    this.font,
    this.decorations = true,
    this.animations = true,
    this.coupleSpaceStyle = CoupleSpaceStyle.classic,
    this.memoryStyle = MemoryStyle.soft,
  });

  static const defaults = ThemeCustomization();

  final String? accent;
  final String? background;
  final String? font;
  final bool decorations;
  final bool animations;
  final CoupleSpaceStyle coupleSpaceStyle;
  final MemoryStyle memoryStyle;

  bool get isDefault => this == defaults;

  ThemeCustomization copyWith({
    ValueGetter<String?>? accent,
    ValueGetter<String?>? background,
    ValueGetter<String?>? font,
    bool? decorations,
    bool? animations,
    CoupleSpaceStyle? coupleSpaceStyle,
    MemoryStyle? memoryStyle,
  }) {
    return ThemeCustomization(
      accent: accent != null ? accent() : this.accent,
      background: background != null ? background() : this.background,
      font: font != null ? font() : this.font,
      decorations: decorations ?? this.decorations,
      animations: animations ?? this.animations,
      coupleSpaceStyle: coupleSpaceStyle ?? this.coupleSpaceStyle,
      memoryStyle: memoryStyle ?? this.memoryStyle,
    );
  }

  /// Wire format shared with `PUT /couple/theme` (snake_case, omits defaults).
  Map<String, dynamic> toJson() => {
        if (accent != null) 'accent': accent,
        if (background != null) 'background': background,
        if (font != null) 'font': font,
        if (!decorations) 'decorations': false,
        if (!animations) 'animations': false,
        if (coupleSpaceStyle != CoupleSpaceStyle.classic) 'couple_space_style': coupleSpaceStyle.name,
        if (memoryStyle != MemoryStyle.soft) 'memory_style': memoryStyle.name,
      };

  factory ThemeCustomization.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;

    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((value) => value.name == name).firstOrNull ?? fallback;

    return ThemeCustomization(
      accent: json['accent'] as String?,
      background: json['background'] as String?,
      font: json['font'] as String?,
      decorations: json['decorations'] as bool? ?? true,
      animations: json['animations'] as bool? ?? true,
      coupleSpaceStyle: byName(CoupleSpaceStyle.values, json['couple_space_style'], CoupleSpaceStyle.classic),
      memoryStyle: byName(MemoryStyle.values, json['memory_style'], MemoryStyle.soft),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeCustomization &&
      other.accent == accent &&
      other.background == background &&
      other.font == font &&
      other.decorations == decorations &&
      other.animations == animations &&
      other.coupleSpaceStyle == coupleSpaceStyle &&
      other.memoryStyle == memoryStyle;

  @override
  int get hashCode => Object.hash(accent, background, font, decorations, animations, coupleSpaceStyle, memoryStyle);
}
