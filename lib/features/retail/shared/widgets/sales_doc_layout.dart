// lib/features/retail/sales/shared/widgets/sales_doc_layout.dart

import 'package:flutter/material.dart';

/// Breakpoint used by header + lines list.
const double kWideRowBreakpoint = 720;

/// Column widths for the wide layout (aligns header row + line rows).
const double kQtyRateColW = 220;
const double kAmtColW = 160;

/// Shared horizontal padding used by BOTH header row + item rows.
const EdgeInsets kSalesDocRowPad = EdgeInsets.symmetric(
  horizontal: 8,
  vertical: 10,
);
