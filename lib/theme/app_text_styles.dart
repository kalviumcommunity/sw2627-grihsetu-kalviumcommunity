import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

TextTheme buildTextTheme(AppPalette p, {required bool webFonts}) {
  TextStyle serif(double s) => webFonts
      ? GoogleFonts.fraunces(
          fontSize: s,
          fontWeight: FontWeight.w600,
          color: p.ink,
          height: 1.15,
          letterSpacing: -s * .01,
        )
      : TextStyle(
          fontSize: s,
          fontWeight: FontWeight.w600,
          color: p.ink,
          height: 1.15,
          letterSpacing: -s * .01,
        );
  TextStyle sans(double s, {FontWeight w = FontWeight.w400, Color? c}) =>
      webFonts
      ? GoogleFonts.inter(
          fontSize: s,
          fontWeight: w,
          color: c ?? p.ink,
          height: 1.5,
        )
      : TextStyle(fontSize: s, fontWeight: w, color: c ?? p.ink, height: 1.5);
  return TextTheme(
    displayLarge: serif(40),
    headlineMedium: serif(28),
    headlineSmall: serif(24),
    titleLarge: serif(20),
    titleMedium: serif(16),
    bodyLarge: sans(15),
    bodyMedium: sans(14),
    bodySmall: sans(13, c: p.muted),
    labelLarge: sans(15, w: FontWeight.w600),
    labelMedium: sans(12, w: FontWeight.w600),
  );
}
