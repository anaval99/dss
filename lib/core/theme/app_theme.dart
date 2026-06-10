import 'package:flutter/material.dart';

/// App-wide light/dark themes. Calm and content-first: a near-neutral surface
/// so the only saturated colors in the UI are the urgency accents (§6). Shapes
/// are softly rounded and consistent; type leans on weight and spacing rather
/// than decoration.
class AppTheme {
  const AppTheme._();

  static const _seed = Color(0xFF4B5BD6);

  // Calm surface neutrals (faint cool cast), tuned per brightness.
  static const _lightSurface = Color(0xFFFBFAFD);
  static const _lightOnSurface = Color(0xFF1B1B22);
  static const _darkSurface = Color(0xFF0F1014);
  static const _darkOnSurface = Color(0xFFE9E9EF);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final base = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final scheme = base.copyWith(
      surface: isLight ? _lightSurface : _darkSurface,
      onSurface: isLight ? _lightOnSurface : _darkOnSurface,
    );

    final radius = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,

      textTheme: _textTheme(scheme),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
        showCheckmark: false,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.4),
        space: 1,
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = (scheme.brightness == Brightness.light
            ? Typography.material2021().black
            : Typography.material2021().white)
        .apply(displayColor: scheme.onSurface, bodyColor: scheme.onSurface);

    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
