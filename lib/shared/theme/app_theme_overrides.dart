import 'package:flutter/material.dart';
import 'app_shape.dart';

ThemeData applyHomeLook(ThemeData base) {
  return base.copyWith(
    // ✅ Cards everywhere match HomeCard
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: AppShape.cardShape(base),
      clipBehavior: Clip.antiAlias,
    ),

    // ✅ Dialogs / sheets match
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppShape.cardRadius),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppShape.cardRadius),
      showDragHandle: true,
    ),

    // ✅ Action chips / outlined buttons match your Home action chips
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.chipR),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    ),

    // ✅ Outlined inputs get the same rounded softness
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      border: OutlineInputBorder(
        borderRadius: AppShape.tileRadius,
        borderSide: AppShape.hairline(base, opacity: 0.20),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppShape.tileRadius,
        borderSide: AppShape.hairline(base, opacity: 0.20),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppShape.tileRadius,
        borderSide: BorderSide(color: base.colorScheme.primary, width: 1.2),
      ),
    ),
  );
}
