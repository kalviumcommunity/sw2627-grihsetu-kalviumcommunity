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
        )
      : TextStyle(
          fontSize: s,
          fontWeight: FontWeight.w600,
          color: p.ink,
          height: 1.15,
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
    displayLarge: serif(40), // Display
    headlineMedium: serif(20), // Heading
    titleMedium: serif(16), // Subheading
    bodyLarge: sans(15), // Body
    bodyMedium: sans(14),
    bodySmall: sans(13, c: p.muted), // Caption
    labelLarge: sans(15, w: FontWeight.w600), // Button
  );
}
