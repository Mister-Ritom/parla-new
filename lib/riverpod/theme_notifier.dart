import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:parla/models/app_theme_setting.dart';
import 'package:parla/theme/theme.dart'; // contains violetLight, violetDark

class ThemeNotifier extends Notifier<FThemeData> {
  AppThemeSettings _settings = const AppThemeSettings();

  @override
  FThemeData build() {
    // listen to system theme changes
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        _handleSystemBrightnessChange;

    return _resolveTheme();
  }

  // --------------------------------------------------
  // TRIGGER REBUILD WHEN SYSTEM THEME CHANGES
  // --------------------------------------------------
  void _handleSystemBrightnessChange() {
    if (_settings.isSystem) {
      state = _resolveTheme(); // Rebuild theme in realtime
    }
  }

  // --------------------------------------------------
  // PUBLIC MUTATORS
  // --------------------------------------------------
  void toggleSystem(bool value) {
    _settings = _settings.copyWith(isSystem: value);
    state = _resolveTheme();
  }

  void setTheme(Brightness value) {
    _settings = _settings.copyWith(theme: value);
    state = _resolveTheme();
  }

  void setThemeColor(String color) {
    _settings = _settings.copyWith(themeColor: color);
    state = _resolveTheme();
  }

  // --------------------------------------------------
  // THEME LOGIC
  // --------------------------------------------------
  FThemeData _resolveTheme() {
    final systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    final brightness = _settings.isSystem ? systemBrightness : _settings.theme;

    if (_settings.themeColor == "violet") {
      return brightness == Brightness.dark ? violetDark : violetLight;
    }

    return violetDark; // fallback
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, FThemeData>(
  () => ThemeNotifier(),
);
