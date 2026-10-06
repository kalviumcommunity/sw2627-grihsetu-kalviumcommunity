import 'package:flutter/material.dart';

class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.border,
    required this.primary,
    required this.primarySoft,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
  });
  final Color background,
      surface,
      ink,
      muted,
      border,
      primary,
      primarySoft,
      accent,
      success,
      warning,
      error;

  static const light = AppPalette(
    background: Color(0xFFF6F2EA),
    surface: Color(0xFFFFFDF8),
    ink: Color(0xFF1D2B2A),
    muted: Color(0xFF6B756F),
    border: Color(0xFFE5DFD2),
    primary: Color(0xFF0F4C45),
    primarySoft: Color(0xFFE6F0EC),
    accent: Color(0xFFC4572F),
    success: Color(0xFF2F7D4F),
    warning: Color(0xFFB7791F),
    error: Color(0xFFB3362D),
  );
  static const dark = AppPalette(
    background: Color(0xFF121A19),
    surface: Color(0xFF1A2423),
    ink: Color(0xFFEEE9DD),
    muted: Color(0xFF9AA59F),
    border: Color(0xFF2B3735),
    primary: Color(0xFF6FC3B2),
    primarySoft: Color(0xFF1F3A36),
    accent: Color(0xFFE8805A),
    success: Color(0xFF6FCF97),
    warning: Color(0xFFE3B04B),
    error: Color(0xFFEF7B72),
  );

  @override
  AppPalette copyWith() => this;
  @override
  AppPalette lerp(AppPalette? other, double t) =>
      other == null ? this : (t < .5 ? this : other);
}

extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
