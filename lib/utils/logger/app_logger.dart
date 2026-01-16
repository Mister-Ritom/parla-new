import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

class AppLogger {
  static const _reset = '\x1B[0m';
  static const _red = '\x1B[31m';
  static const _yellow = '\x1B[33m';
  static const _blue = '\x1B[34m';

  static void info({
    required String name,
    required String message,
    String? title,
    String? description,
    Object? exception,
    StackTrace? stack,
  }) {
    final clean = _format(
      type: "INFO",
      name: name,
      message: message,
      title: title,
      description: description,
      exception: exception,
      stack: stack,
    );

    if (kDebugMode) {
      print("$_blue$clean$_reset");
      dev.postEvent("app.info", {"logger": name, "message": clean});
    } else {
      dev.log(
        message,
        name: name,
        level: 800,
        error: exception,
        stackTrace: stack,
      );
    }
  }

  static void warn({
    required String name,
    required String message,
    String? title,
    String? description,
    Object? exception,
    StackTrace? stack,
  }) {
    final clean = _format(
      type: "WARN",
      name: name,
      message: message,
      title: title,
      description: description,
      exception: exception,
      stack: stack,
    );

    if (kDebugMode) {
      print("$_yellow$clean$_reset");
      dev.postEvent("app.warn", {"logger": name, "message": clean});
    } else {
      dev.log(
        message,
        name: name,
        level: 900,
        error: exception,
        stackTrace: stack,
      );
    }
  }

  static void error({
    required String name,
    required String message,
    String? title,
    String? description,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    final clean = _format(
      type: "ERROR",
      name: name,
      message: message,
      title: title,
      description: description,
      exception: exception,
      stack: stackTrace,
    );

    if (kDebugMode) {
      print("$_red$clean$_reset");
      dev.postEvent("app.error", {"logger": name, "message": clean});
    } else {
      dev.log(
        message,
        name: name,
        level: 1000,
        error: exception,
        stackTrace: stackTrace,
      );
    }
  }

  static String _format({
    required String type,
    required String name,
    required String message,
    String? title,
    String? description,
    Object? exception,
    StackTrace? stack,
  }) {
    final buffer = StringBuffer();

    buffer.writeln("[$name][$type]");
    if (title != null) buffer.writeln("Title: $title");
    if (description != null) buffer.writeln("Description: $description");
    buffer.writeln("Message: $message");

    if (exception != null) {
      buffer.writeln("Exception: $exception");
    }

    if (stack != null) {
      buffer.writeln("StackTrace:\n$stack");
    }

    // ⭐ No color codes returned
    return buffer.toString();
  }
}
