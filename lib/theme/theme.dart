import 'package:forui/forui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// -----------------------------------------------------------------------------
// CUSTOM THEME USING YOUR FONTS
// -----------------------------------------------------------------------------

FThemeData get violetLight {
  const colors = FColors(
    brightness: Brightness.light,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    barrier: Color(0x33000000),
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF030712),
    primary: Color(0xFF7C3AED),
    primaryForeground: Color(0xFFF9FAFB),
    secondary: Color(0xFFF3F4F6),
    secondaryForeground: Color(0xFF111827),
    muted: Color(0xFFF3F4F6),
    mutedForeground: Color(0xFF6B7280),
    destructive: Color(0xFFEF4444),
    destructiveForeground: Color(0xFFF9FAFB),
    error: Color(0xFFEF4444),
    errorForeground: Color(0xFFF9FAFB),
    border: Color(0xFFE5E7EB),
  );

  final typography = _typography(colors: colors);
  final style = _style(colors: colors, typography: typography);

  return FThemeData(colors: colors, typography: typography, style: style);
}

FThemeData get violetDark {
  const colors = FColors(
    brightness: Brightness.dark,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    barrier: Color(0x7A000000),
    background: Color(0xFF030712),
    foreground: Color(0xFFF9FAFB),
    primary: Color(0xFF6D28D9),
    primaryForeground: Color(0xFFF9FAFB),
    secondary: Color(0xFF1F2937),
    secondaryForeground: Color(0xFFF9FAFB),
    muted: Color(0xFF454545),
    mutedForeground: Color(0xFF9CA3AF),
    destructive: Color(0xFF7F1D1D),
    destructiveForeground: Color(0xFFF9FAFB),
    error: Color(0xFF7F1D1D),
    errorForeground: Color(0xFFF9FAFB),
    border: Color(0xFF1F2937),
  );

  final typography = _typography(colors: colors);
  final style = _style(colors: colors, typography: typography);

  return FThemeData(colors: colors, typography: typography, style: style);
}

// -----------------------------------------------------------------------------
// TYPOGRAPHY — USING YOUR LOCAL INTER FONT
// -----------------------------------------------------------------------------

FTypography _typography({required FColors colors}) {
  return FTypography(
    xs: TextStyle(
      color: colors.foreground,
      fontFamily: 'Inter',
      fontSize: 12,
      height: 1,
    ),
    sm: TextStyle(
      color: colors.foreground,
      fontFamily: 'Inter',
      fontSize: 14,
      height: 1.25,
    ),
    base: TextStyle(
      color: colors.foreground,
      fontFamily: 'Inter',
      fontSize: 16,
      height: 1.5,
    ),
    lg: TextStyle(
      color: colors.foreground,
      fontFamily: 'Inter',
      fontSize: 18,
      height: 1.75,
    ),
    xl: TextStyle(
      color: colors.foreground,
      fontFamily: 'Inter',
      fontSize: 20,
      height: 1.75,
    ),

    // HEADINGS USE PACIFICO FONT
    xl2: TextStyle(
      color: colors.foreground,
      fontFamily: 'Pacifico',
      fontSize: 26,
      height: 1.2,
    ),
    xl3: TextStyle(
      color: colors.foreground,
      fontFamily: 'Pacifico',
      fontSize: 34,
      height: 1.2,
    ),
    xl4: TextStyle(
      color: colors.foreground,
      fontFamily: 'Pacifico',
      fontSize: 42,
      height: 1.2,
    ),

    // LARGE HEADERS STILL INTER
    xl5: TextStyle(
      color: colors.foreground,
      fontFamily: 'Inter',
      fontSize: 48,
      height: 1,
    ),
    xl6: TextStyle(
      color: colors.foreground,
      fontFamily: 'Inter',
      fontSize: 60,
      height: 1,
    ),
    xl7: TextStyle(
      color: colors.foreground,
      fontFamily: 'Inter',
      fontSize: 72,
      height: 1,
    ),
    xl8: TextStyle(
      color: colors.foreground,
      fontFamily: 'Pacifico',
      fontSize: 96,
      height: 1,
    ),
  );
}

// -----------------------------------------------------------------------------
// COMPONENT STYLE (unchanged except for icon + border)
// -----------------------------------------------------------------------------
FStyle _style({required FColors colors, required FTypography typography}) {
  return FStyle(
    formFieldStyle: FFormFieldStyle.inherit(
      colors: colors,
      typography: typography,
    ),
    focusedOutlineStyle: FFocusedOutlineStyle(
      color: colors.primary,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    ),
    iconStyle: IconThemeData(color: colors.primary, size: 20),
    tappableStyle: FTappableStyle(),
    borderRadius: const FLerpBorderRadius.all(Radius.circular(8), min: 24),
    borderWidth: 1,
    pagePadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    shadow: const [
      BoxShadow(color: Color(0x0d000000), offset: Offset(0, 1), blurRadius: 2),
    ],
  );
}
