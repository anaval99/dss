import 'package:flutter/material.dart';

import '../../domain/models/urgency.dart';

/// Visual tokens for an [Urgency] band. Color is one of three signals (accent
/// bar + tinted background + text label) so urgency is never conveyed by color
/// alone (accessibility, §6).
@immutable
class UrgencyColors {
  const UrgencyColors({
    required this.accent,
    required this.tint,
    required this.onTint,
  });

  /// Saturated color for the left accent bar / dot.
  final Color accent;

  /// Subtle row background wash.
  final Color tint;

  /// Text/label color that reads on [tint].
  final Color onTint;
}

/// Maps urgency to colors. Overdue and today both read **red**; soon is amber;
/// later is green. Tuned tokens; dark-mode variants refined in Phase 7.
class UrgencyPalette {
  const UrgencyPalette._();

  // Base accents (§6).
  static const _red = Color(0xFFE5484D);
  static const _amber = Color(0xFFF5A623);
  static const _green = Color(0xFF30A46C);

  static UrgencyColors of(Urgency urgency, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final (accent, tintLight, tintDark) = switch (urgency) {
      Urgency.overdue || Urgency.today => (
          _red,
          const Color(0xFFFFF1F1),
          const Color(0xFF3A1F22),
        ),
      Urgency.soon => (
          _amber,
          const Color(0xFFFFF7E8),
          const Color(0xFF382C16),
        ),
      Urgency.later => (
          _green,
          const Color(0xFFEAF7F0),
          const Color(0xFF122C20),
        ),
    };
    return UrgencyColors(
      accent: accent,
      tint: dark ? tintDark : tintLight,
      onTint: dark ? accent : _darken(accent),
    );
  }

  /// A slightly darker accent for label text on a light tint (better contrast).
  static Color _darken(Color c) =>
      HSLColor.fromColor(c).withLightness(0.34).toColor();
}
