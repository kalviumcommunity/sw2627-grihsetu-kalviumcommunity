import 'package:flutter/material.dart';

extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette(Theme.of(this).brightness);
}

class AppPalette {
  const AppPalette(this.brightness);

  final Brightness brightness;
  bool get isDark => brightness == Brightness.dark;

  Color get canvas =>
      isDark ? const Color(0xFF121A19) : const Color(0xFFF6F2EA);
  Color get surface =>
      isDark ? const Color(0xFF1A2423) : const Color(0xFFFFFDF8);
  Color get raised => surface;
  Color get ink => isDark ? const Color(0xFFEEE9DD) : const Color(0xFF1D2B2A);
  Color get muted => isDark ? const Color(0xFF9AA59F) : const Color(0xFF6B756F);
  Color get border =>
      isDark ? const Color(0xFF2B3735) : const Color(0xFFE5DFD2);
  Color get primary =>
      isDark ? const Color(0xFF6FC3B2) : const Color(0xFF0F4C45);
  Color get primarySoft =>
      isDark ? const Color(0xFF1F3A36) : const Color(0xFFE6F0EC);
  Color get accent =>
      isDark ? const Color(0xFFE8805A) : const Color(0xFFC4572F);
  Color get accentSoft =>
      isDark ? const Color(0xFF3A2820) : const Color(0xFFF8E6DD);
  Color get success =>
      isDark ? const Color(0xFF6FCF97) : const Color(0xFF2F7D4F);
  Color get warning =>
      isDark ? const Color(0xFFE3B04B) : const Color(0xFFB7791F);
  Color get danger =>
      isDark ? const Color(0xFFEF7B72) : const Color(0xFFB3362D);
  Color get shimmer =>
      isDark ? const Color(0xFF2B3735) : const Color(0xFFE5DFD2);
}
