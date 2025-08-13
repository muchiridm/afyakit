//lib/shared/services/snack_service.dart

import 'package:flutter/material.dart';

class SnackService {
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static void showSuccess(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showSnack(message, backgroundColor: Colors.green, duration: duration);
  }

  static void showError(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnack(message, backgroundColor: Colors.redAccent, duration: duration);
  }

  static void showInfo(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showSnack(message, backgroundColor: Colors.blueAccent, duration: duration);
  }

  static void _showSnack(
    String message, {
    required Color backgroundColor,
    required Duration duration,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars(); // optional: remove previous
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  static void showValidationErrors(List<String> errors) {
    showError(errors.join('\n'), duration: const Duration(seconds: 4));
  }
}
