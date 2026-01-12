// lib/features/retail/quotes/widgets/quote_lines_sliver.dart

import 'package:flutter/material.dart';

import '../controllers/quote_editor_controller.dart';
import '../controllers/quote_editor_state.dart';
import 'line_edit_dialog.dart';

class QuoteLinesSliver extends StatelessWidget {
  const QuoteLinesSliver({
    super.key,
    required this.state,
    required this.ctl,
    required this.readOnly,
  });

  final QuoteEditorState state;
  final QuoteEditorController ctl;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final lines = state.draft.lines;

    if (lines.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: _EmptyLines(readOnly: readOnly),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      sliver: SliverList.separated(
        itemCount: lines.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final l = lines[i];

          final rawTitle = l.tile.tileTitle.trim();
          final rawDesc = (l.tile.tileDesc ?? '').trim();
          final title =
              (rawTitle.isEmpty || rawTitle == 'Item') && rawDesc.isNotEmpty
              ? rawDesc
              : (rawTitle.isNotEmpty ? rawTitle : 'Item');

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _LineMetaRow(
                qty: l.quantity,
                rate: l.rate,
                amount: l.amount,
              ),
            ),
            trailing: readOnly
                ? null
                : IconButton(
                    tooltip: 'Remove',
                    onPressed: () => ctl.removeLine(i),
                    icon: const Icon(Icons.delete_outline),
                  ),
            onTap: readOnly
                ? null
                : () async {
                    final res = await showDialog<LineEditResult>(
                      context: context,
                      builder: (_) =>
                          LineEditDialog(qty: l.quantity, rate: l.rate),
                    );
                    if (res == null) return;
                    ctl.setLineQty(i, res.qty);
                    ctl.setLineRate(i, res.rate);
                  },
          );
        },
      ),
    );
  }
}

class _EmptyLines extends StatelessWidget {
  const _EmptyLines({required this.readOnly});
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_basket_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              readOnly
                  ? 'No items on this quote.'
                  : 'No items yet. Add from the catalog below.',
              style: t.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineMetaRow extends StatelessWidget {
  const _LineMetaRow({
    required this.qty,
    required this.rate,
    required this.amount,
  });

  final int qty;
  final num rate;
  final num amount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    Widget chip(String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Text('$label $value', style: t.bodySmall),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Qty', qty.toString()),
        chip('Rate', _money(rate)),
        chip('Amount', _money(amount)),
      ],
    );
  }
}

/// Money formatting: lightweight, no intl dependency.
String _money(num v) {
  final n = v.round();
  final s = n.toString();
  final buf = StringBuffer();

  for (int i = 0; i < s.length; i++) {
    final left = s.length - i;
    buf.write(s[i]);
    if (left > 1 && left % 3 == 1) buf.write(',');
  }

  return 'KES ${buf.toString()}';
}
