import 'package:flutter/material.dart';

extension ColorX on Color {
  Color opacityAlpha(double opacity) {
    final clampedOpacity = opacity.clamp(0, 100);
    final alpha = ((clampedOpacity / 100) * 255).round();
    return withAlpha(alpha);
  }
}
