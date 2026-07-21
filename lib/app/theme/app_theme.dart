import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light({
    String styleKey = 'emerald',
    String appFontKey = 'cairo',
  }) {
    final palette = _AppThemePalette.light(styleKey);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      primary: palette.primary,
      secondary: palette.secondary,
      surface: palette.surface,
      brightness: Brightness.light,
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.foreground,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.3),
        ),
      ),
      dividerTheme: const DividerThemeData(space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );

    return _withAppFont(theme, appFontKey);
  }

  static ThemeData dark({
    String styleKey = 'emerald',
    String appFontKey = 'cairo',
  }) {
    final palette = _AppThemePalette.dark(styleKey);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      primary: palette.primary,
      secondary: palette.secondary,
      surface: palette.surface,
      brightness: Brightness.dark,
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.foreground,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.3),
        ),
      ),
      dividerTheme: const DividerThemeData(space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );

    return _withAppFont(theme, appFontKey);
  }

  static ThemeData _withAppFont(ThemeData theme, String appFontKey) {
    final families = _fontFamilies(appFontKey);
    return theme.copyWith(
      textTheme: _applyFont(theme.textTheme, families),
      primaryTextTheme: _applyFont(theme.primaryTextTheme, families),
    );
  }

  static _FontFamilies _fontFamilies(String appFontKey) {
    return switch (appFontKey.trim().toLowerCase()) {
      'tajawal' => const _FontFamilies(
        preferred: 'Tajawal',
        fallbacks: ['Segoe UI', 'Tahoma', 'Arial', 'sans-serif'],
      ),
      'noto' => const _FontFamilies(
        preferred: 'Noto Sans Arabic',
        fallbacks: ['Segoe UI', 'Tahoma', 'Arial', 'sans-serif'],
      ),
      'ibm' => const _FontFamilies(
        preferred: 'IBM Plex Sans Arabic',
        fallbacks: ['Segoe UI', 'Tahoma', 'Arial', 'sans-serif'],
      ),
      _ => const _FontFamilies(
        preferred: 'Cairo',
        fallbacks: ['Segoe UI', 'Tahoma', 'Arial', 'sans-serif'],
      ),
    };
  }

  static TextTheme _applyFont(TextTheme theme, _FontFamilies families) {
    return theme.copyWith(
      displayLarge: _styleWithFont(theme.displayLarge, families),
      displayMedium: _styleWithFont(theme.displayMedium, families),
      displaySmall: _styleWithFont(theme.displaySmall, families),
      headlineLarge: _styleWithFont(theme.headlineLarge, families),
      headlineMedium: _styleWithFont(theme.headlineMedium, families),
      headlineSmall: _styleWithFont(theme.headlineSmall, families),
      titleLarge: _styleWithFont(theme.titleLarge, families),
      titleMedium: _styleWithFont(theme.titleMedium, families),
      titleSmall: _styleWithFont(theme.titleSmall, families),
      bodyLarge: _styleWithFont(theme.bodyLarge, families),
      bodyMedium: _styleWithFont(theme.bodyMedium, families),
      bodySmall: _styleWithFont(theme.bodySmall, families),
      labelLarge: _styleWithFont(theme.labelLarge, families),
      labelMedium: _styleWithFont(theme.labelMedium, families),
      labelSmall: _styleWithFont(theme.labelSmall, families),
    );
  }

  static TextStyle? _styleWithFont(TextStyle? style, _FontFamilies families) {
    return style?.copyWith(
      fontFamily: families.preferred,
      fontFamilyFallback: families.fallbacks,
      letterSpacing: 0,
    );
  }
}

class _FontFamilies {
  const _FontFamilies({required this.preferred, required this.fallbacks});

  final String preferred;
  final List<String> fallbacks;
}

class _AppThemePalette {
  const _AppThemePalette({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.foreground,
  });

  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color foreground;

  factory _AppThemePalette.light(String key) {
    return switch (key) {
      'indigo' => const _AppThemePalette(
        primary: Color(0xFF3657A7),
        secondary: Color(0xFFD08C3C),
        background: Color(0xFFF5F6FB),
        surface: Colors.white,
        foreground: Color(0xFF17203A),
      ),
      'sunrise' => const _AppThemePalette(
        primary: Color(0xFF9A3412),
        secondary: Color(0xFF0F766E),
        background: Color(0xFFFFF7ED),
        surface: Colors.white,
        foreground: Color(0xFF3A2417),
      ),
      'rose' => const _AppThemePalette(
        primary: Color(0xFF9F1239),
        secondary: Color(0xFF2563EB),
        background: Color(0xFFFFF1F2),
        surface: Colors.white,
        foreground: Color(0xFF3F1724),
      ),
      'graphite' => const _AppThemePalette(
        primary: Color(0xFF334155),
        secondary: Color(0xFFCA8A04),
        background: Color(0xFFF8FAFC),
        surface: Colors.white,
        foreground: Color(0xFF111827),
      ),
      _ => const _AppThemePalette(
        primary: Color(0xFF0F766E),
        secondary: Color(0xFFD1A34A),
        background: Color(0xFFF4F1E8),
        surface: Colors.white,
        foreground: Color(0xFF12302C),
      ),
    };
  }

  factory _AppThemePalette.dark(String key) {
    return switch (key) {
      'indigo' => const _AppThemePalette(
        primary: Color(0xFF8EA4FF),
        secondary: Color(0xFFF2B36B),
        background: Color(0xFF101424),
        surface: Color(0xFF171D33),
        foreground: Colors.white,
      ),
      'sunrise' => const _AppThemePalette(
        primary: Color(0xFFFFB68A),
        secondary: Color(0xFF5EEAD4),
        background: Color(0xFF1E1510),
        surface: Color(0xFF2A1C15),
        foreground: Colors.white,
      ),
      'rose' => const _AppThemePalette(
        primary: Color(0xFFFF8FA8),
        secondary: Color(0xFF93C5FD),
        background: Color(0xFF201116),
        surface: Color(0xFF2B1820),
        foreground: Colors.white,
      ),
      'graphite' => const _AppThemePalette(
        primary: Color(0xFFCBD5E1),
        secondary: Color(0xFFFACC15),
        background: Color(0xFF0F172A),
        surface: Color(0xFF1E293B),
        foreground: Colors.white,
      ),
      _ => const _AppThemePalette(
        primary: Color(0xFF4FD1C5),
        secondary: Color(0xFFE4B968),
        background: Color(0xFF0E1716),
        surface: Color(0xFF152120),
        foreground: Colors.white,
      ),
    };
  }
}
