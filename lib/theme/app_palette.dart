import 'package:flutter/material.dart';

extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette(Theme.of(this).brightness);
}

class AppPalette {
  const AppPalette(this.brightness);

  final Brightness brightness;
  bool get isDark => brightness == Brightness.dark;

  Color get canvas =>
      isDark ? const Color(0xFF101917) : const Color(0xFFF6F2EA);
  Color get surface =>
      isDark ? const Color(0xFF192421) : const Color(0xFFFFFDFA);
  Color get raised => isDark ? const Color(0xFF22312D) : Colors.white;
  Color get ink => isDark ? const Color(0xFFEAF2EF) : const Color(0xFF172522);
  Color get muted => isDark ? const Color(0xFFB4C3BE) : const Color(0xFF53635E);
  Color get border =>
      isDark ? const Color(0xFF42534D) : const Color(0xFFD5DCD5);
  Color get accent =>
      isDark ? const Color(0xFF8FD2C2) : const Color(0xFF0F4C45);
  Color get accentSoft =>
      isDark ? const Color(0xFF29463F) : const Color(0xFFE2F0E9);
  Color get success =>
      isDark ? const Color(0xFF9BD7A5) : const Color(0xFF246B36);
  Color get warning =>
      isDark ? const Color(0xFFFFD18A) : const Color(0xFF805400);
  Color get danger =>
      isDark ? const Color(0xFFFFB4AB) : const Color(0xFF9B2921);
  Color get shimmer =>
      isDark ? const Color(0xFF33443E) : const Color(0xFFE4E9E3);
}
