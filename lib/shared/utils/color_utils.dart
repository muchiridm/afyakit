// lib/shared/utils/color_utils.dart
import 'package:flutter/material.dart';

/// "#RGB", "#RRGGBB", or "#AARRGGBB" → Color, with a safe fallback.
Color colorFromHex(
  String hex, {
  String fallback = '#2196F3', // ← hardcoded default, no TenantConfig
}) {
  String sanitize(String s) {
    var h = s.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.startsWith('0x') || h.startsWith('0X')) h = h.substring(2);
    if (h.length == 3) {
      // #RGB → RRGGBB
      h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
    }
    if (h.length == 6) {
      // add opaque alpha
      h = 'FF$h';
    }
    return h;
  }

  String h = sanitize(hex);
  int? value = int.tryParse(h, radix: 16);

  if (value == null || h.length != 8) {
    final fb = sanitize(fallback);
    value = int.tryParse(fb, radix: 16) ?? 0xFF2196F3;
  }

  return Color(value);
}
