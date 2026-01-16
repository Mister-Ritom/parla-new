import 'dart:ui';

class AppThemeSettings {
  final bool isSystem;
  final Brightness theme; // Brightness.light or Brightness.dark
  final String themeColor; // currently: 'violet'

  const AppThemeSettings({
    this.isSystem = true,
    this.theme = Brightness.dark,
    this.themeColor = "violet",
  });

  AppThemeSettings copyWith({
    bool? isSystem,
    Brightness? theme,
    String? themeColor,
  }) {
    return AppThemeSettings(
      isSystem: isSystem ?? this.isSystem,
      theme: theme ?? this.theme,
      themeColor: themeColor ?? this.themeColor,
    );
  }
}
