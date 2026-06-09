import 'package:flutter/material.dart';

/// App-wide light/dark themes. Deliberately restrained — a calm, content-first
/// surface so the only saturated colors are the urgency accents (§6). The
/// distinctive design pass (motion, spacing, refined tokens) lands in Phase 7.
class AppTheme {
  const AppTheme._();

  static const _seed = Color(0xFF3A5BD9);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
    );
  }
}
