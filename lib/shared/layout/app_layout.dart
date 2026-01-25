// lib/shared/layout/app_layout.dart
import 'dart:math' as math;
import 'package:flutter/widgets.dart';

abstract class AppLayout {
  static const double pageMaxW = 820;
  static const double memberPageMaxW = 820;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  static double clampWidth(double maxWidth, double cap) =>
      math.min(maxWidth, cap);
}
