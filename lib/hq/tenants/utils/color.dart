import 'package:flutter/material.dart';
import 'package:afyakit/hq/tenants/models/tenant_config.dart';

/// "#RGB", "#RRGGBB", or "#AARRGGBB" → Color (defensive)
Color colorFromHex(
  String hex, {
  String fallback = TenantConfig.defaultColorHex,
}) {
  String sanitize(String s) {
    var h = s.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.startsWith('0x') || h.startsWith('0X')) h = h.substring(2);
    if (h.length == 3) {
      h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}'; // #RGB → RRGGBB
    }
    if (h.length == 6) h = 'FF$h'; // add opaque alpha
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
