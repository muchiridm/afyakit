// lib/features/retail/sales/shared/sales_doc/layout.dart

import 'package:flutter/material.dart';

/// Breakpoint used by header + lines list.
const double kWideRowBreakpoint = 720;

/// Column widths for the wide layout (aligns header row + line rows).
const double kQtyRateColW = 220;
const double kAmtColW = 160;

/// Right-side action rail sizing (must match row widgets).
const double kActionRailW = 40;
const double kActionRailGap = 8; // spacing between amount and rail

/// Shared horizontal padding used by BOTH header row + item rows.
const EdgeInsets kSalesDocRowPad = EdgeInsets.symmetric(
  horizontal: 8,
  vertical: 10,
);
