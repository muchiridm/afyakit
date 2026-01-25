// lib/features/retail/sales/shared/widgets/sales_doc_lines_row.dart

import 'package:afyakit/features/retail/shared/widgets/sales_doc_models.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_formatters.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_line_helpers.dart';
import 'package:flutter/material.dart';

class SalesDocWideLineRow extends StatelessWidget {
  const SalesDocWideLineRow({
    super.key,
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

  // ✅ now all async so we can show dialogs in the callbacks
  final Future<void> Function(int index)? onEditName;
  final Future<void> Function(int index)? onEditQtyRate;
  final Future<void> Function(int index)? onRemoveLine;

  bool get _canEditName => editable && onEditName != null;
  bool get _canEditQtyRate => editable && onEditQtyRate != null;
  bool get _canRemove => editable && onRemoveLine != null;

  bool get _canTapRow => _canEditQtyRate || _canEditName;
  bool get _canLongPress => _canEditName;

  Future<void> _tapRow() async {
    // ✅ Prefer the combined dialog first
    if (_canEditQtyRate) {
      await onEditQtyRate!(index);
      return;
    }
    if (_canEditName) {
      await onEditName!(index);
      return;
    }
  }

  Future<void> _longPressRow() async {
    if (_canEditName) {
      await onEditName!(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showActions = _canEditQtyRate || _canRemove;

    return InkWell(
      onTap: _canTapRow ? _tapRow : null,
      onLongPress: _canLongPress ? _longPressRow : null,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _TwoRowLineBody(
              currencyCode: currencyCode,
              line: line,
              chipTight: false,
            ),
          ),
          if (showActions) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: _ActionColumn.kW,
              child: _ActionColumn(
                canEdit: _canEditQtyRate,
                canRemove: _canRemove,
                onEdit: _canEditQtyRate ? () => onEditQtyRate!(index) : null,
                onRemove: _canRemove ? () => onRemoveLine!(index) : null,
              ),
            ),
          ] else
            const SizedBox(width: 12 + _ActionColumn.kW),
        ],
      ),
    );
  }
}

class SalesDocNarrowLineRow extends StatelessWidget {
  const SalesDocNarrowLineRow({
    super.key,
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

  // ✅ async
  final Future<void> Function(int index)? onEditName;
  final Future<void> Function(int index)? onEditQtyRate;
  final Future<void> Function(int index)? onRemoveLine;

  bool get _canEditName => editable && onEditName != null;
  bool get _canEditQtyRate => editable && onEditQtyRate != null;
  bool get _canRemove => editable && onRemoveLine != null;

  bool get _canTapRow => _canEditQtyRate || _canEditName;
  bool get _canLongPress => _canEditName;

  Future<void> _tapRow() async {
    // ✅ Prefer combined dialog
    if (_canEditQtyRate) {
      await onEditQtyRate!(index);
      return;
    }
    if (_canEditName) {
      await onEditName!(index);
      return;
    }
  }

  Future<void> _longPressRow() async {
    if (_canEditName) {
      await onEditName!(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showActions = _canEditQtyRate || _canRemove;

    return InkWell(
      onTap: _canTapRow ? _tapRow : null,
      onLongPress: _canLongPress ? _longPressRow : null,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _TwoRowLineBody(
              currencyCode: currencyCode,
              line: line,
              chipTight: true,
            ),
          ),
          if (showActions) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: _ActionColumn.kW,
              child: _ActionColumn(
                canEdit: _canEditQtyRate,
                canRemove: _canRemove,
                onEdit: _canEditQtyRate ? () => onEditQtyRate!(index) : null,
                onRemove: _canRemove ? () => onRemoveLine!(index) : null,
              ),
            ),
          ] else
            const SizedBox(width: 10 + _ActionColumn.kW),
        ],
      ),
    );
  }
}

class _TwoRowLineBody extends StatelessWidget {
  const _TwoRowLineBody({
    required this.currencyCode,
    required this.line,
    required this.chipTight,
  });

  final String currencyCode;
  final SalesDocLineVm line;
  final bool chipTight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = lineDisplayText(line);
    final amount = money(line.amount, currencyCode);

    final chipPad = chipTight
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 7);

    final chipGap = chipTight ? 10.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
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
          spacing: chipGap,
          runSpacing: 8,
          children: [
            _pill(theme, 'Qty: ${decimal.format(line.qty)}', padding: chipPad),
            _pill(
              theme,
              'Rate: ${decimal.format(line.rate)}',
              padding: chipPad,
            ),
          ],
        ),
      ],
    );
  }

  static Widget _pill(
    ThemeData theme,
    String text, {
    required EdgeInsets padding,
  }) {
    return Container(
      padding: padding,
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

  static const double kW = 40;

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
