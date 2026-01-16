// lib/shared/layout/app_layout.dart

import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// One place to define app page widths so every screen matches Home.
abstract class AppLayout {
  /// Matches HomeScreen._maxW
  static const double pageMaxW = 820;

  /// Matches HomeScreen._memberMaxW (optional usage)
  static const double memberPageMaxW = 640;

  /// Matches HomeScreen padding
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  /// Utility: clamp a width to a max.
  static double clampWidth(double maxWidth, double cap) =>
      math.min(maxWidth, cap);
}
