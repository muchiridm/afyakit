import 'package:flutter/material.dart';

abstract final class AppShape {
  // ─────────────────────────────────────────────────────────────
  // Radii
  // ─────────────────────────────────────────────────────────────
  static const double cardR = 16;
  static const double tileR = 14;
  static const double chipR = 14;

  // ─────────────────────────────────────────────────────────────
  // Spacing (USED IN SizedBox → MUST be const)
  // ─────────────────────────────────────────────────────────────
  static const double gap4 = 4;
  static const double gap6 = 6;
  static const double gap8 = 8;
  static const double gap10 = 10;
  static const double gap12 = 12;
  static const double gap16 = 16;
  static const double gap24 = 24;

  // ─────────────────────────────────────────────────────────────
  // Padding presets
  // ─────────────────────────────────────────────────────────────
  static const EdgeInsets cardPad = EdgeInsets.all(14);
  static const EdgeInsets tilePad = EdgeInsets.all(12);

  // ─────────────────────────────────────────────────────────────
  // Border radii (non-const helpers)
  // ─────────────────────────────────────────────────────────────
  static BorderRadius get cardRadius => BorderRadius.circular(cardR);

  static BorderRadius get tileRadius => BorderRadius.circular(tileR);

  static BorderRadius get chipRadius => BorderRadius.circular(chipR);

  // ─────────────────────────────────────────────────────────────
  // Borders / shapes
  // ─────────────────────────────────────────────────────────────
  static BorderSide hairline(ThemeData theme, {double opacity = 0.25}) {
    return BorderSide(color: theme.dividerColor.withOpacity(opacity));
  }

  static RoundedRectangleBorder cardShape(ThemeData theme) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardR),
      side: hairline(theme, opacity: 0.25),
    );
  }

  static BoxDecoration tileDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(tileR),
      border: Border.all(color: theme.dividerColor.withOpacity(0.20)),
    );
  }
}
