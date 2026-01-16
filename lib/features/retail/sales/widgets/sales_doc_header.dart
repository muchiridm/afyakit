import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared formatters (keep here so both header + body use the same ones)
final nf = NumberFormat.decimalPattern();
final df = DateFormat.yMMMEd();

/// Breakpoint used by both header and body
const double kWideRowBreakpoint = 720;

/// Column widths for wide mode (body)
const double kQtyColW = 90;
const double kRateColW = 120;
const double kAmtColW = 140;

@immutable
class SalesDocLineVm {
  const SalesDocLineVm({
    required this.title,
    this.subtitle,
    required this.qty,
    required this.rate,
  });

  final String title;
  final String? subtitle;
  final num qty;
  final num rate;

  num get amount => qty * rate;
}

@immutable
class SalesDocMetaVm {
  const SalesDocMetaVm({
    required this.partyName,
    required this.docNumberOrId,
    required this.status,
    required this.currencyCode,
    required this.total,
    required this.date,
  });

  final String partyName;
  final String docNumberOrId;
  final String status;
  final String currencyCode;
  final num total;
  final DateTime? date;
}

enum SalesDocMode { view, edit }

String money(num v, String currencyCode) {
  final code = currencyCode.trim();
  return '${code.isEmpty ? '' : '$code '}${nf.format(v)}';
}

/// ───────────────────────── Header ─────────────────────────

class SalesDocHeader extends StatelessWidget {
  const SalesDocHeader({
    super.key,
    required this.title,
    required this.meta,
    this.trailing,
    this.compact = true,
  });

  final String title;
  final SalesDocMetaVm meta;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final party = meta.partyName.trim().isEmpty
        ? 'Customer'
        : meta.partyName.trim();

    final pills = <Widget>[
      _pill(Icons.confirmation_number_outlined, meta.docNumberOrId),
      if (meta.date != null) _pill(Icons.event_outlined, df.format(meta.date!)),
      if (meta.status.trim().isNotEmpty) _pill(Icons.info_outline, meta.status),
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
              // Try to keep trailing on same row.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      party,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: isWide
                            ? trailing!
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: trailing!,
                              ),
                      ),
                    ),
                  ],
                ],
              ),

              SizedBox(height: gap),

              if (pills.isNotEmpty)
                isWide
                    ? Row(
                        children: [
                          for (final p in pills)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: p,
                            ),
                        ],
                      )
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

  static Widget _pill(IconData icon, String text) {
    final v = text.trim().isEmpty ? '-' : text.trim();
    return Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(v)],
      ),
    );
  }
}

/// ───────────────────────── Total bar ─────────────────────────

class SalesDocTotalBar extends StatelessWidget {
  const SalesDocTotalBar({
    super.key,
    required this.label,
    required this.total,
    required this.currencyCode,
  });

  final String label;
  final num total;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            money(total, currencyCode),
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
