import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_theme_tokens.dart';
import 'theme_customization.dart';
import 'theme_definition.dart';
import 'theme_registry.dart';

abstract final class AppTheme {
  /// The default (brand) theme in light mode.
  static ThemeData light() =>
      build(ThemeRegistry.defaultTheme, Brightness.light);

  /// Resolves a theme definition + the couple's customization into
  /// [ThemeData] carrying [AppThemeTokens]. Unknown preset keys fall back to
  /// the theme defaults, so a stale or tampered setting can never break UI.
  static ThemeData build(
    ThemeDefinition definition,
    Brightness brightness, {
    ThemeCustomization customization = ThemeCustomization.defaults,
  }) {
    // Dark-only themes (Midnight, Starry Night) stay dark in light mode.
    brightness = definition.palette(brightness).brightness;
    final t = resolveTokens(
      definition,
      brightness,
      customization: customization,
    );
    final isDark = brightness == Brightness.dark;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: t.primary,
          brightness: brightness,
        ).copyWith(
          primary: t.primary,
          onPrimary: t.onPrimary,
          secondary: t.secondary,
          onSecondary: t.textPrimary,
          secondaryContainer: t.secondary,
          onSecondaryContainer: t.textPrimary,
          surface: t.surface,
          onSurface: t.textPrimary,
          onSurfaceVariant: t.textSecondary,
          surfaceContainerLowest: t.surface,
          surfaceContainerLow: t.surface,
          surfaceContainer: t.surfaceMuted,
          surfaceContainerHigh: t.surfaceMuted,
          surfaceContainerHighest: t.surfaceMuted,
          error: t.error,
          onError: isDark ? t.background : Colors.white,
          outline: t.border,
          outlineVariant: t.border,
        );

    final barColor = switch (t.navigation) {
      NavigationStyle.flat => t.background,
      NavigationStyle.tinted => Color.alphaBlend(
        t.primary.withValues(alpha: isDark ? 0.14 : 0.07),
        t.background,
      ),
      NavigationStyle.elevated => t.surface,
    };

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(t.buttonRadius),
    );
    const buttonSize = Size(64, 52);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      fontFamily: t.body.fontFamily,
      extensions: [t],
      splashFactory: InkSparkle.splashFactory,

      textTheme: TextTheme(
        displayLarge: t.display,
        headlineMedium: t.title,
        titleLarge: t.title,
        titleMedium: t.heading,
        titleSmall: t.label,
        bodyLarge: t.body,
        bodyMedium: t.body,
        bodySmall: t.caption,
        labelLarge: t.button.copyWith(color: null),
        labelMedium: t.label,
        labelSmall: t.overline,
      ),

      iconTheme: IconThemeData(color: t.textPrimary, size: 24),

      appBarTheme: AppBarTheme(
        backgroundColor: barColor,
        foregroundColor: t.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: t.navigation == NavigationStyle.flat ? 0 : 1,
        shadowColor: t.textPrimary.withValues(alpha: 0.2),
        centerTitle: false,
        titleTextStyle: t.title.copyWith(
          fontSize: (t.title.fontSize ?? 22) * 0.9,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: t.navigation == NavigationStyle.flat
            ? t.background
            : t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: t.navigation == NavigationStyle.elevated ? 3 : 0,
        shadowColor: t.textPrimary.withValues(alpha: 0.25),
        indicatorColor: t.primary.withValues(alpha: isDark ? 0.24 : 0.14),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? t.primary
                : t.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => t.label.copyWith(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? t.primary
                : t.textSecondary,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: t.surface,
        elevation: t.cardElevation,
        shadowColor: t.textPrimary.withValues(alpha: 0.2),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.cardRadius),
          side: t.cardBorder ? BorderSide(color: t.border) : BorderSide.none,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        labelStyle: t.body.copyWith(color: t.textSecondary),
        floatingLabelStyle: t.label.copyWith(color: t.primary),
        hintStyle: t.body.copyWith(color: t.textSecondary),
        helperStyle: t.caption,
        errorStyle: t.caption.copyWith(color: t.error),
        prefixIconColor: t.textSecondary,
        border: _inputBorder(t, t.border),
        enabledBorder: _inputBorder(t, t.border),
        focusedBorder: _inputBorder(t, t.primary, width: 1.6),
        errorBorder: _inputBorder(t, t.error),
        focusedErrorBorder: _inputBorder(t, t.error, width: 1.6),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          disabledBackgroundColor: t.surfaceMuted,
          disabledForegroundColor: t.textSecondary,
          shape: buttonShape,
          textStyle: t.button,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          disabledBackgroundColor: t.surfaceMuted,
          disabledForegroundColor: t.textSecondary,
          shape: buttonShape,
          textStyle: t.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          foregroundColor: t.primary,
          side: BorderSide(color: t.border, width: 1.2),
          shape: buttonShape,
          textStyle: t.button,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: t.primary,
          textStyle: t.label.copyWith(fontSize: 14),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.primary,
        foregroundColor: t.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        extendedTextStyle: t.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.buttonRadius + 2),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: t.surface,
        selectedColor: t.secondary,
        side: BorderSide(color: t.border),
        labelStyle: t.label.copyWith(color: t.textPrimary),
        secondaryLabelStyle: t.label.copyWith(color: t.textPrimary),
        checkmarkColor: t.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.chipRadius),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: t.surfaceMuted,
          foregroundColor: t.textSecondary,
          selectedBackgroundColor: t.surface,
          selectedForegroundColor: t.textPrimary,
          side: BorderSide(color: t.border),
          textStyle: t.label,
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: t.textSecondary,
        textColor: t.textPrimary,
        titleTextStyle: t.body.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: t.caption,
        minVerticalPadding: AppSpacing.smd,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? t.onPrimary : t.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : t.surfaceMuted,
        ),
        trackOutlineColor: WidgetStatePropertyAll(t.border),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.surfaceMuted,
        circularTrackColor: Colors.transparent,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.surface,
        showDragHandle: true,
        dragHandleColor: t.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(t.sheetRadius),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: t.title.copyWith(fontSize: 20),
        contentTextStyle: t.body.copyWith(color: t.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.sheetRadius - 4),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.textPrimary,
        contentTextStyle: t.body.copyWith(color: t.background),
        actionTextColor: isDark ? t.primaryDark : t.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.buttonRadius),
        ),
      ),

      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      dividerColor: t.border,
    );
  }

  static OutlineInputBorder _inputBorder(
    AppThemeTokens t,
    Color color, {
    double width = 1,
  }) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(t.buttonRadius),
    borderSide: BorderSide(color: color, width: width),
  );

  static AppThemeTokens resolveTokens(
    ThemeDefinition definition,
    Brightness brightness, {
    ThemeCustomization customization = ThemeCustomization.defaults,
  }) {
    final isDark = brightness == Brightness.dark;
    var palette = definition.palette(brightness);

    final accent = definition.accentPresets
        .where((p) => p.key == customization.accent)
        .firstOrNull;
    if (accent != null) {
      // In dark mode accents switch to a lighter variant, which needs the dark
      // palette's (dark) text colour on top of it, not the light one.
      palette = isDark && accent.darkPrimary != null
          ? palette.copyWith(
              primary: accent.darkPrimary,
              onPrimary: definition.palette(Brightness.dark).onPrimary,
            )
          : palette.copyWith(
              primary: accent.primary,
              onPrimary: accent.onPrimary,
            );
    }

    final background = definition.backgroundPresets
        .where((p) => p.key == customization.background)
        .firstOrNull;
    if (background != null) {
      palette = palette.copyWith(
        background: isDark
            ? (background.darkBackground ?? palette.background)
            : background.background,
        surface: isDark
            ? (background.darkSurface ?? palette.surface)
            : background.surface,
      );
    }

    final font = definition.fontPresets
        .where((p) => p.key == customization.font)
        .firstOrNull;
    final typography = definition.typography;
    final displayFamily = font?.displayFamily ?? typography.displayFamily;
    final bodyFamily = font?.bodyFamily ?? typography.bodyFamily;

    TextStyle style(
      String? family,
      double size,
      FontWeight weight,
      Color color,
      double height, {
      double spacing = 0,
    }) {
      return TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        // Bundled fonts are variable fonts: drive the weight axis explicitly.
        fontVariations: family == null
            ? null
            : [FontVariation('wght', weight.value.toDouble())],
        letterSpacing: spacing,
        color: color,
        height: height,
      );
    }

    final scale = font?.displayFamily != null ? 1.0 : typography.displayScale;

    // Semantic colours a theme does not set are derived per brightness.
    final success =
        palette.success ?? (isDark ? AppColors.successDark : AppColors.success);
    final warning =
        palette.warning ?? (isDark ? AppColors.warningDark : AppColors.warning);
    final error =
        palette.error ?? (isDark ? AppColors.errorDark : AppColors.error);
    final info = palette.info ?? (isDark ? AppColors.infoDark : AppColors.info);
    final surfaceMuted =
        palette.surfaceMuted ??
        Color.lerp(palette.surface, palette.border, isDark ? 0.45 : 0.35)!;
    final paper =
        palette.paper ?? (isDark ? AppColors.paperDark : AppColors.paper);

    final handwritingFamily = typography.handwritingFamily;
    final isMonoHand = handwritingFamily == 'CourierPrime';

    return AppThemeTokens(
      themeKey: definition.key,
      brightness: brightness,
      primary: palette.primary,
      primaryDark: Color.lerp(
        palette.primary,
        isDark ? Colors.white : Colors.black,
        0.12,
      )!,
      onPrimary: palette.onPrimary,
      secondary: palette.secondary,
      accent: palette.accent,
      background: palette.background,
      surface: palette.surface,
      surfaceMuted: surfaceMuted,
      paper: paper,
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      border: palette.border,
      success: success,
      warning: warning,
      error: error,
      info: info,
      display: style(
        displayFamily,
        32 * scale,
        typography.displayWeight,
        palette.textPrimary,
        1.15,
        spacing: typography.displayLetterSpacing,
      ),
      title: style(
        displayFamily,
        22 * scale,
        typography.displayWeight,
        palette.textPrimary,
        1.25,
        spacing: typography.displayLetterSpacing,
      ),
      heading: style(bodyFamily, 17, FontWeight.w700, palette.textPrimary, 1.3),
      subtitle: style(
        bodyFamily,
        16,
        FontWeight.w400,
        palette.textSecondary,
        1.5,
      ),
      body: style(bodyFamily, 15, FontWeight.w400, palette.textPrimary, 1.5),
      label: style(
        bodyFamily,
        13,
        FontWeight.w600,
        palette.textPrimary,
        1.3,
        spacing: 0.2,
      ),
      caption: style(
        bodyFamily,
        12.5,
        FontWeight.w500,
        palette.textSecondary,
        1.4,
      ),
      overline: style(
        bodyFamily,
        11,
        FontWeight.w700,
        palette.textSecondary,
        1.2,
        spacing: 1.2,
      ),
      handwriting: style(
        handwritingFamily,
        isMonoHand ? 15 : 20,
        isMonoHand ? FontWeight.w700 : FontWeight.w500,
        palette.primary,
        1.2,
      ),
      button: style(bodyFamily, 15, FontWeight.w700, palette.onPrimary, 1.2),
      cardRadius: definition.components.cardRadius,
      buttonRadius: definition.components.buttonRadius,
      chipRadius: definition.components.chipRadius,
      sheetRadius: definition.components.sheetRadius,
      photoRadius: definition.components.photoRadius,
      cardBorder: definition.components.cardBorder,
      cardElevation: definition.components.cardElevation,
      navigation: definition.components.navigation,
      ornament: definition.ornament,
      ornamentsEnabled:
          customization.decorations && definition.ornament != OrnamentKind.none,
      decoration: definition.decoration,
      animation: definition.animation,
      decorationsEnabled:
          customization.decorations &&
          definition.decoration.kind != DecorationKind.none,
      animationsEnabled:
          customization.animations && definition.animation.isAnimated,
      reduceMotion: false,
      coupleSpaceStyle: customization.coupleSpaceStyle,
      memoryStyle: customization.memoryStyle,
    );
  }
}
