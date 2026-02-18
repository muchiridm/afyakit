// lib/features/retail/sales/shared/sales_doc/lines.dart

import 'package:flutter/material.dart';
import 'helpers.dart';
import 'layout.dart';
import 'models.dart';

class SalesDocLinesList extends StatelessWidget {
  const SalesDocLinesList({
    super.key,
    required this.currencyCode,
    required this.lines,
    this.mode = SalesDocMode.view,

    // unified dialog edit
    this.onEditLine,

    // inline edit hooks
    this.onEditName,
    this.onEditQtyRate,

    this.onRemoveLine,
    this.showWideHeader = true,
    this.embedInParentScroll = false,
  });

  final String currencyCode;
  final List<SalesDocLineVm> lines;
  final SalesDocMode mode;

  final Future<void> Function(int index)? onEditLine;

  final Future<void> Function(int index, String nextName)? onEditName;
  final Future<void> Function(int index, int nextQty, num nextRate)?
  onEditQtyRate;

  final Future<void> Function(int index)? onRemoveLine;

  final bool showWideHeader;
  final bool embedInParentScroll;

  bool get _editable =>
      mode == SalesDocMode.edit &&
      (onEditLine != null ||
          onEditQtyRate != null ||
          onEditName != null ||
          onRemoveLine != null);

  bool get _hasAnyRowActions {
    if (mode != SalesDocMode.edit) return false;
    return (onEditLine != null ||
            onEditName != null ||
            onEditQtyRate != null) ||
        (onRemoveLine != null);
  }

  Future<void> _editLine(int index) async {
    final fn = onEditLine;
    if (fn == null) return;
    await fn(index);
  }

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const Center(child: Text('No line items.'));

    // If unified editor exists, route inline callbacks to it (ignore args).
    final Future<void> Function(int, String)? effectiveOnEditName =
        (onEditLine != null) ? (i, _) => _editLine(i) : onEditName;

    final Future<void> Function(int, int, num)? effectiveOnEditQtyRate =
        (onEditLine != null) ? (i, __, ___) => _editLine(i) : onEditQtyRate;

    Widget buildRow(BuildContext context, bool isWide, int i) {
      final li = lines[i];
      return Padding(
        padding: kSalesDocRowPad,
        child: isWide
            ? _WideLineRow(
                currencyCode: currencyCode,
                index: i,
                line: li,
                editable: _editable,
                onEditName: effectiveOnEditName,
                onEditQtyRate: effectiveOnEditQtyRate,
                onRemoveLine: onRemoveLine,
              )
            : _NarrowLineRow(
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

// ───────────────────────── Row widgets (merged) ─────────────────────────

class _WideLineRow extends StatelessWidget {
  const _WideLineRow({
    required this.currencyCode,
    required this.index,
    required this.line,
    required this.editable,
    required this.onEditName,
    required this.onEditQtyRate,
    required this.onRemoveLine,
  });

  final String currencyCode;
  final int index;
  final SalesDocLineVm line;
  final bool editable;

  final Future<void> Function(int index, String nextName)? onEditName;
  final Future<void> Function(int index, int nextQty, num nextRate)?
  onEditQtyRate;
  final Future<void> Function(int index)? onRemoveLine;

  bool get _canEditName => editable && onEditName != null;
  bool get _canEditQtyRate => editable && onEditQtyRate != null;
  bool get _canRemove => editable && onRemoveLine != null;

  bool get _canTapRow => _canEditQtyRate || _canEditName;

  Future<void> _tapRow() async {
    if (_canEditQtyRate) {
      await onEditQtyRate!(index, line.qty.toInt(), line.rate);
      return;
    }
    if (_canEditName) {
      await onEditName!(index, line.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showActions = _canEditQtyRate || _canRemove;

    return InkWell(
      onTap: _canTapRow ? _tapRow : null,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _TwoRowLineBody(currencyCode: currencyCode, line: line),
          ),
          if (showActions) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: kActionRailW,
              child: _ActionColumn(
                canEdit: _canEditQtyRate,
                canRemove: _canRemove,
                onEdit: _canEditQtyRate
                    ? () => onEditQtyRate!(index, line.qty.toInt(), line.rate)
                    : null,
                onRemove: _canRemove ? () => onRemoveLine!(index) : null,
              ),
            ),
          ] else
            const SizedBox(width: 12 + kActionRailW),
        ],
      ),
    );
  }
}

class _NarrowLineRow extends StatelessWidget {
  const _NarrowLineRow({
    required this.currencyCode,
    required this.index,
    required this.line,
    required this.editable,
    required this.onEditName,
    required this.onEditQtyRate,
    required this.onRemoveLine,
  });

  final String currencyCode;
  final int index;
  final SalesDocLineVm line;
  final bool editable;

  final Future<void> Function(int index, String nextName)? onEditName;
  final Future<void> Function(int index, int nextQty, num nextRate)?
  onEditQtyRate;
  final Future<void> Function(int index)? onRemoveLine;

  bool get _canEditName => editable && onEditName != null;
  bool get _canEditQtyRate => editable && onEditQtyRate != null;
  bool get _canRemove => editable && onRemoveLine != null;

  bool get _canTapRow => _canEditQtyRate || _canEditName;

  Future<void> _tapRow() async {
    if (_canEditQtyRate) {
      await onEditQtyRate!(index, line.qty.toInt(), line.rate);
      return;
    }
    if (_canEditName) {
      await onEditName!(index, line.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showActions = _canEditQtyRate || _canRemove;

    return InkWell(
      onTap: _canTapRow ? _tapRow : null,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _TwoRowLineBody(currencyCode: currencyCode, line: line),
          ),
          if (showActions) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: kActionRailW,
              child: _ActionColumn(
                canEdit: _canEditQtyRate,
                canRemove: _canRemove,
                onEdit: _canEditQtyRate
                    ? () => onEditQtyRate!(index, line.qty.toInt(), line.rate)
                    : null,
                onRemove: _canRemove ? () => onRemoveLine!(index) : null,
              ),
            ),
          ] else
            const SizedBox(width: 10 + kActionRailW),
        ],
      ),
    );
  }
}

class _TwoRowLineBody extends StatelessWidget {
  const _TwoRowLineBody({required this.currencyCode, required this.line});

  final String currencyCode;
  final SalesDocLineVm line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = line.title.trim().isEmpty ? 'Item' : line.title.trim();
    final subtitle = (line.subtitle ?? '').trim();
    final amount = money(line.amount, currencyCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.2,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(
                          0.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amount,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _pill(theme, 'Qty: ${decimal.format(line.qty)}'),
            _pill(theme, 'Rate: ${decimal.format(line.rate)}'),
          ],
        ),
      ],
    );
  }

  static Widget _pill(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActionColumn extends StatelessWidget {
  const _ActionColumn({
    required this.canEdit,
    required this.canRemove,
    required this.onEdit,
    required this.onRemove,
  });

  final bool canEdit;
  final bool canRemove;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (canRemove)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Remove line',
            icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
            onPressed: onRemove == null ? null : () => onRemove!(),
          ),
        if (canEdit)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit == null ? null : () => onEdit!(),
          ),
      ],
    );
  }
}
