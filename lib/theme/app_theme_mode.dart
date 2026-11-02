import 'package:flutter/material.dart';

/// In-memory theme preference. Light is deliberately the product default.
final class AppThemeMode extends ValueNotifier<ThemeMode> {
  AppThemeMode._() : super(ThemeMode.light);

  static final AppThemeMode instance = AppThemeMode._();

  void setMode(ThemeMode mode) => value = mode;
}

extension ThemeModeLabel on ThemeMode {
  String get displayLabel => switch (this) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };
}
