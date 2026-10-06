import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

class GrihSetuApp extends StatelessWidget {
  const GrihSetuApp({super.key, this.webFonts = true});
  final bool webFonts; // false in tests, so no font downloads
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppStrings.appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(webFonts: webFonts),
    darkTheme: AppTheme.dark(webFonts: webFonts),
    themeMode: ThemeMode.system,
    home: const AppShell(),
  );
}
