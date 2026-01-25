import 'package:flutter/material.dart';
import 'sales_doc_header.dart';

class SalesDocLinesList extends StatelessWidget {
  const SalesDocLinesList({
    super.key,
    required this.currencyCode,
    required this.lines,
    this.mode = SalesDocMode.view,
    this.onEditName,
    this.onEditQtyRate,
    this.onQtyChange,
    this.onEditRate,
    this.onRemoveLine,
    this.showWideHeader = true,
  });

  final String currencyCode;
  final List<SalesDocLineVm> lines;
  final SalesDocMode mode;

  final Future<void> Function(int index)? onEditName;
  final Future<void> Function(int index)? onEditQtyRate;

  final void Function(int index, int nextQty)? onQtyChange;
  final Future<void> Function(int index)? onEditRate;

  final void Function(int index)? onRemoveLine;

  final bool showWideHeader;

  bool get _editable =>
      mode == SalesDocMode.edit &&
      (onEditQtyRate != null ||
          onQtyChange != null ||
          onEditName != null ||
          onEditRate != null ||
          onRemoveLine != null);

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const Center(child: Text('No line items.'));

    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= kWideRowBreakpoint;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              sliver: SliverToBoxAdapter(
                child: (isWide && showWideHeader)
                    ? _WideHeaderRow(currencyCode: currencyCode)
                    : const SizedBox.shrink(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              sliver: SliverList.separated(
                itemCount: lines.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, thickness: 0.4),
                itemBuilder: (context, i) {
                  final li = lines[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: isWide
                        ? _buildWideRow(context, i, li)
                        : _buildNarrowRow(context, i, li),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWideRow(BuildContext context, int index, SalesDocLineVm li) {
    final theme = Theme.of(context);

    final canEditName = _editable && onEditName != null;
    final canRemove = _editable && onRemoveLine != null;

    final canEditQtyRate = _editable && onEditQtyRate != null;

    final canQtyLegacy =
        _editable && onQtyChange != null && onEditQtyRate == null;
    final canRateLegacy =
        _editable && onEditRate != null && onEditQtyRate == null;

    final display = _lineDisplayText(li);
    final hasDisplay = display.trim().isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: hasDisplay
                      ? Text(
                          display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (canEditName) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: 'Edit line name',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => onEditName!(index),
                  ),
                ],
              ],
            ),
          ),
        ),

        SizedBox(
          width: kQtyColW,
          child: canEditQtyRate
              ? _editCell(
                  context,
                  text: nf.format(li.qty),
                  onTap: () => onEditQtyRate!(index),
                )
              : canQtyLegacy
              ? _qtyInlineControls(
                  theme,
                  li.qty.round(),
                  onDec: () => onQtyChange!(index, li.qty.round() - 1),
                  onInc: () => onQtyChange!(index, li.qty.round() + 1),
                )
              : Text(
                  nf.format(li.qty),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),

        const SizedBox(width: 12),

        SizedBox(
          width: kRateColW,
          child: canEditQtyRate
              ? _editCell(
                  context,
                  text: nf.format(li.rate),
                  onTap: () => onEditQtyRate!(index),
                )
              : canRateLegacy
              ? _editCell(
                  context,
                  text: nf.format(li.rate),
                  onTap: () => onEditRate!(index),
                )
              : Text(
                  nf.format(li.rate),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),

        const SizedBox(width: 12),

        SizedBox(
          width: kAmtColW + (canRemove ? 36 : 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                money(li.amount, currencyCode),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (canRemove) ...[
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: 'Remove line',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onRemoveLine!(index),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowRow(BuildContext context, int index, SalesDocLineVm li) {
    final theme = Theme.of(context);
    final display = _lineDisplayText(li);
    final hasDisplay = display.trim().isNotEmpty;

    if (!_editable) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDisplay)
                  Text(
                    display,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Qty: ${nf.format(li.qty)}  •  Rate: ${nf.format(li.rate)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            money(li.amount, currencyCode),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }

    final canEditName = onEditName != null;
    final canEditQtyRate = onEditQtyRate != null;
    final canRemove = onRemoveLine != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: hasDisplay
                        ? Text(
                            display,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (canEditName) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'Edit line name',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => onEditName!(index),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (canEditQtyRate)
                    _editPill(
                      context,
                      label: 'Qty: ${nf.format(li.qty)}',
                      onTap: () => onEditQtyRate!(index),
                    )
                  else
                    Text(
                      'Qty: ${nf.format(li.qty)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(width: 12),
                  if (canEditQtyRate)
                    _editPill(
                      context,
                      label: 'Rate: ${nf.format(li.rate)}',
                      onTap: () => onEditQtyRate!(index),
                    )
                  else
                    Text(
                      'Rate: ${nf.format(li.rate)}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 98 + (canRemove ? 36 : 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                money(li.amount, currencyCode),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (canRemove) ...[
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: 'Remove line',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onRemoveLine!(index),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _editCell(
    BuildContext context, {
    required String text,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _editPill(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit, size: 14),
          ],
        ),
      ),
    );
  }

  String _lineDisplayText(SalesDocLineVm li) {
    final title = li.title.trim();
    final subtitle = (li.subtitle ?? '').trim();
    final isPlaceholderTitle = title.toLowerCase() == 'item';

    if ((title.isEmpty || isPlaceholderTitle) && subtitle.isNotEmpty)
      return subtitle;
    if (subtitle.isEmpty) return title;
    if (title.isEmpty) return subtitle;
    return '$title — $subtitle';
  }

  Widget _qtyInlineControls(
    ThemeData theme,
    int qty, {
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              icon: const Icon(Icons.remove, size: 16),
              tooltip: 'Decrease quantity',
              onPressed: onDec,
            ),
            Text(
              '$qty',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            IconButton(
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              icon: const Icon(Icons.add, size: 16),
              tooltip: 'Increase quantity',
              onPressed: onInc,
            ),
          ],
        ),
      ),
    );
  }
}

class _WideHeaderRow extends StatelessWidget {
  const _WideHeaderRow({required this.currencyCode});
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final style = t.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: t.bodySmall?.color?.withOpacity(0.75),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text('Item', style: style)),
          SizedBox(
            width: kQtyColW,
            child: Text('Qty', textAlign: TextAlign.right, style: style),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: kRateColW,
            child: Text('Rate', textAlign: TextAlign.right, style: style),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: kAmtColW,
            child: Text('Amount', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}
