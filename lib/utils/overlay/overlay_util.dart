import 'package:easy_overlay/easy_overlay.dart';
import 'package:flutter/material.dart';

class OverlayUtil {
  static void showTopOverlay(String message) {
    EasyOverlay.showToast(
      message: message,
      alignment: const Alignment(0, -0.8),
      duration: const Duration(seconds: 4),
    );
  }
}
