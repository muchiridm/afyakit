// lib/features/retail/sales/shared/widgets/sales_doc_lines.dart

import 'package:afyakit/features/retail/shared/widgets/sales_doc_layout.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_doc_models.dart';
import 'package:flutter/material.dart';

import 'sales_doc_lines_row.dart';

/// Column widths / breakpoints.
/// `kWideRowBreakpoint` comes from sales_doc_header.dart.
const double kQtyRateColW = 220;
const double kAmtColW = 160;

/// Right-side action rail sizing (must match row widgets).
const double kActionRailW = 40;
const double kActionRailGap = 8; // spacing between amount and rail

/// Shared horizontal padding used by BOTH header row + item rows.
/// Keeping this identical is what makes the columns align.
const EdgeInsets kSalesDocRowPad = EdgeInsets.symmetric(
  horizontal: 8,
  vertical: 10,
);

class SalesDocLinesList extends StatelessWidget {
  const SalesDocLinesList({
    super.key,
    required this.currencyCode,
    required this.lines,
    this.mode = SalesDocMode.view,

    // ─────────────── callbacks ───────────────
    this.onEditLine, // edit all fields in one dialog
    this.onEditName,
    this.onEditQtyRate,

    /// Legacy (older UI patterns)
    this.onQtyChange,
    this.onEditRate,

    this.onRemoveLine,
    this.showWideHeader = true,

    // when true, this widget will NOT scroll; parent scrolls.
    this.embedInParentScroll = false,
  });

  final String currencyCode;
  final List<SalesDocLineVm> lines;
  final SalesDocMode mode;

  /// Single “edit everything” entry point (name + qty + rate).
  /// If provided, row tap + pencil both route here.
  final Future<void> Function(int index)? onEditLine;

  final Future<void> Function(int index)? onEditName;
  final Future<void> Function(int index)? onEditQtyRate;

  /// Legacy (older UI patterns)
  final void Function(int index, int nextQty)? onQtyChange;
  final Future<void> Function(int index)? onEditRate;

  /// ✅ MUST be async so callers can show confirm dialogs before removing.
  final Future<void> Function(int index)? onRemoveLine;

  final bool showWideHeader;
  final bool embedInParentScroll;

  bool get _editable =>
      mode == SalesDocMode.edit &&
      (onEditLine != null ||
          onEditQtyRate != null ||
          onQtyChange != null ||
          onEditName != null ||
          onEditRate != null ||
          onRemoveLine != null);

  bool get _hasAnyRowActions {
    if (mode != SalesDocMode.edit) return false;
    // If unified edit exists, "edit" exists.
    final canEdit =
        onEditLine != null || onEditName != null || onEditQtyRate != null;
    final canRemove = onRemoveLine != null;
    return canEdit || canRemove;
  }

  Future<void> _editLine(int index) async {
    final fn = onEditLine;
    if (fn == null) return;
    await fn(index);
  }

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const Center(child: Text('No line items.'));

    // If a unified editor exists, route both “tap row” and “pencil” to it.
    final Future<void> Function(int index)? effectiveOnEditName =
        (onEditLine != null) ? _editLine : onEditName;

    final Future<void> Function(int index)? effectiveOnEditQtyRate =
        (onEditLine != null) ? _editLine : onEditQtyRate;

    Widget buildRow(BuildContext context, bool isWide, int i) {
      final li = lines[i];
      return Padding(
        padding: kSalesDocRowPad,
        child: isWide
            ? SalesDocWideLineRow(
                currencyCode: currencyCode,
                index: i,
                line: li,
                editable: _editable,
                onEditName: effectiveOnEditName,
                onEditQtyRate: effectiveOnEditQtyRate,
                onRemoveLine: onRemoveLine,
              )
            : SalesDocNarrowLineRow(
                currencyCode: currencyCode,
                index: i,
                line: li,
                editable: _editable,
                onEditName: effectiveOnEditName,
                onEditQtyRate: effectiveOnEditQtyRate,
                onRemoveLine: onRemoveLine,
              ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= kWideRowBreakpoint;

        if (embedInParentScroll) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Column(
              children: [
                if (isWide && showWideHeader) ...[
                  _WideHeaderRow(showActionCol: _hasAnyRowActions),
                  const SizedBox(height: 12),
                ],
                ...List.generate(lines.length, (i) {
                  final row = buildRow(context, isWide, i);

                  if (i == lines.length - 1) return row;

                  return Column(
                    children: [row, const Divider(height: 1, thickness: 0.4)],
                  );
                }),
              ],
            ),
          );
        }

        // Existing behavior: this widget owns scrolling
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              sliver: SliverToBoxAdapter(
                child: (isWide && showWideHeader)
                    ? _WideHeaderRow(showActionCol: _hasAnyRowActions)
                    : const SizedBox.shrink(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              sliver: SliverList.separated(
                itemCount: lines.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, thickness: 0.4),
                itemBuilder: (context, i) => buildRow(context, isWide, i),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WideHeaderRow extends StatelessWidget {
  const _WideHeaderRow({required this.showActionCol});

  /// If editable, rows show a dedicated action column (delete/edit stacked).
  final bool showActionCol;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final style = t.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: t.bodySmall?.color?.withOpacity(0.75),
    );

    final trailingW = showActionCol ? (kActionRailGap + kActionRailW) : 0.0;

    return Padding(
      padding: kSalesDocRowPad.copyWith(top: 0, bottom: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text('Item', style: style)),
          const SizedBox(width: 16),
          SizedBox(
            width: kQtyRateColW,
            child: Row(
              children: [
                Expanded(
                  child: Text('Qty', textAlign: TextAlign.right, style: style),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Rate', textAlign: TextAlign.right, style: style),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: kAmtColW + trailingW,
            child: Text('Amount', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}
