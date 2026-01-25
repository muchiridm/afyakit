// lib/features/retail/sales/shared/widgets/sales_doc_header.dart

import 'package:flutter/material.dart';

import 'sales_doc_layout.dart';
import 'sales_doc_models.dart';
import 'sales_formatters.dart';
import 'sales_doc_status_chip.dart';

class SalesDocHeader extends StatelessWidget {
  const SalesDocHeader({
    super.key,
    required this.title,
    required this.meta,
    this.leading,
    this.trailing,
    this.compact = true,
    this.showDocNumber = true,
    this.showDate = true,
    this.showStatus = true,
  });

  final String title;
  final SalesDocMetaVm meta;

  final Widget? leading;
  final Widget? trailing;

  final bool compact;
  final bool showDocNumber;
  final bool showDate;
  final bool showStatus;

  // A shared height rail for trailing actions (Pick / status / trash).
  // This is what fixes the “one icon floating” issue across Web/Linux fonts.
  static const double _kTrailingRailH = 36.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final party = meta.partyName.trim().isEmpty
        ? 'Customer'
        : meta.partyName.trim();

    // Keep the "pills" consistent in size with your existing header chips.
    final VisualDensity pillDensity = compact
        ? const VisualDensity(horizontal: -2, vertical: -2)
        : VisualDensity.compact;

    final pills = <Widget>[
      if (showDocNumber)
        _pill(
          context,
          Icons.confirmation_number_outlined,
          meta.docNumberOrId,
          density: pillDensity,
        ),
      if (showDate && meta.date != null)
        _pill(
          context,
          Icons.event_outlined,
          formatDocDate(meta.date!),
          density: pillDensity,
        ),
      if (showStatus && meta.status.trim().isNotEmpty)
        _statusPill(context, meta.status, density: pillDensity),
    ];

    final pad = compact
        ? const EdgeInsets.fromLTRB(16, 8, 16, 6)
        : const EdgeInsets.fromLTRB(16, 12, 16, 8);

    final gap = compact ? 6.0 : 10.0;

    return Padding(
      padding: pad,
      child: LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth >= kWideRowBreakpoint;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                // ✅ Center everything on the same horizontal rail.
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    // Keep leading visually centered too.
                    SizedBox(
                      height: _kTrailingRailH,
                      child: Center(child: leading),
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Left block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          party,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (title.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            title.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall?.copyWith(
                              color: t.bodySmall?.color?.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Right block (pinned to the right edge)
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        // Don't let trailing steal the whole row.
                        maxWidth: isWide
                            ? c.maxWidth * 0.55
                            : c.maxWidth * 0.60,
                      ),
                      child: Align(
                        // ✅ Center-right, not top-right.
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          // ✅ The important bit: rail height.
                          height: _kTrailingRailH,
                          child: isWide
                              ? _TrailingRail(child: trailing!)
                              : _RightAlignedHScroll(
                                  child: _TrailingRail(child: trailing!),
                                ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (pills.isNotEmpty) SizedBox(height: gap),
              if (pills.isNotEmpty)
                isWide
                    ? Wrap(spacing: 8, runSpacing: 8, children: pills)
                    : SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: pills.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => pills[i],
                        ),
                      ),
            ],
          );
        },
      ),
    );
  }

  static Widget _pill(
    BuildContext context,
    IconData icon,
    String text, {
    required VisualDensity density,
  }) {
    final t = Theme.of(context).textTheme;
    final v = text.trim().isEmpty ? '-' : text.trim();

    return Chip(
      visualDensity: density,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(v, style: t.labelSmall),
        ],
      ),
    );
  }

  static Widget _statusPill(
    BuildContext context,
    String statusRaw, {
    required VisualDensity density,
  }) {
    return SalesDocStatusChip(status: statusRaw, visualDensity: density);
  }
}

/// Ensures the trailing row is vertically centered inside the rail.
/// This prevents mixed-height widgets (Chip / OutlinedButton / IconButton)
/// from “floating” on Web/Linux.
class _TrailingRail extends StatelessWidget {
  const _TrailingRail({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(child: child);
  }
}

/// Keeps the trailing actions right-aligned even when scrolling on narrow screens.
class _RightAlignedHScroll extends StatelessWidget {
  const _RightAlignedHScroll({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Directionality(textDirection: TextDirection.ltr, child: child),
      ),
    );
  }
}
