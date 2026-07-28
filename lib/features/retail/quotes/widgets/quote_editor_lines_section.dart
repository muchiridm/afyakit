// lib/features/retail/sales/quotes/widgets/quote_editor_lines_section.dart

import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/shared/sales_doc/dialogs.dart';
import 'package:afyakit/features/retail/shared/sales_doc/lines.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum QuoteEditorLineKind { catalog, manual, unknown }

@immutable
class QuoteEditorLineBinding {
  const QuoteEditorLineBinding._(
    this.kind, {
    required this.key,
    this.manualId,
    this.tileId,
  });

  final QuoteEditorLineKind kind;
  final String key;
  final String? manualId;
  final String? tileId;

  factory QuoteEditorLineBinding.catalog({
    required String tileId,
    required String key,
  }) {
    return QuoteEditorLineBinding._(
      QuoteEditorLineKind.catalog,
      tileId: tileId,
      key: key,
    );
  }

  factory QuoteEditorLineBinding.manual({
    required String manualId,
    required String key,
  }) {
    return QuoteEditorLineBinding._(
      QuoteEditorLineKind.manual,
      manualId: manualId,
      key: key,
    );
  }

  factory QuoteEditorLineBinding.unknown({required String key}) {
    return QuoteEditorLineBinding._(QuoteEditorLineKind.unknown, key: key);
  }
}

List<QuoteEditorLineBinding> buildQuoteLineBindings(
  QuoteLinesState linesState,
) {
  return linesState.lines
      .map((Object line) {
        if (line is CatalogQuoteLine) {
          return QuoteEditorLineBinding.catalog(
            tileId: line.tile.id,
            key: line.key,
          );
        }

        if (line is ManualQuoteLine) {
          return QuoteEditorLineBinding.manual(
            manualId: line.manualId,
            key: line.key,
          );
        }

        if (line case final dynamic unknownLine) {
          final String key = switch (unknownLine) {
            final CatalogQuoteLine l => l.key,
            final ManualQuoteLine l => l.key,
            _ => '',
          };
          return QuoteEditorLineBinding.unknown(key: key);
        }
      })
      .toList(growable: false);
}

List<SalesDocLineVm> buildQuoteLineVms(
  QuoteLinesState linesState, {
  required bool requirePrices,
}) {
  return linesState.lines
      .map((Object line) {
        if (line is CatalogQuoteLine) {
          final String title = line.effectiveName.trim().isEmpty
              ? 'Item'
              : line.effectiveName.trim();

          final String? subtitle =
              (line.effectiveDescription ?? '').trim().isEmpty
              ? null
              : line.effectiveDescription;

          return SalesDocLineVm(
            title: title,
            subtitle: subtitle,
            qty: line.qty,
            rate: requirePrices ? line.effectiveRate : 0,
          );
        }

        if (line is ManualQuoteLine) {
          final String title = line.name.trim().isEmpty
              ? 'Item'
              : line.name.trim();
          final String? subtitle = (line.description ?? '').trim().isEmpty
              ? null
              : line.description;

          return SalesDocLineVm(
            title: title,
            subtitle: subtitle,
            qty: line.qty,
            rate: requirePrices ? line.rate : 0,
          );
        }

        return const SalesDocLineVm(
          title: 'Item',
          subtitle: null,
          qty: 1,
          rate: 0,
        );
      })
      .toList(growable: false);
}

class QuoteEditorLinesSection extends ConsumerWidget {
  const QuoteEditorLinesSection({
    super.key,
    required this.busy,
    required this.linesState,
    required this.requirePrices,
    required this.isMemberScoped,
    required this.currencyCode,
  });

  final bool busy;
  final QuoteLinesState linesState;
  final bool requirePrices;
  final bool isMemberScoped;
  final String currencyCode;

  QuoteLinesController _linesCtl(WidgetRef ref) {
    return ref.read(quoteLinesControllerProvider.notifier);
  }

  bool _isManualAt(
    int index,
    List<QuoteEditorLineBinding> bindings,
    QuoteLinesState state,
  ) {
    final QuoteEditorLineBinding binding = bindings[index];
    final Object line = state.lines[index];
    return binding.kind == QuoteEditorLineKind.manual &&
        line is ManualQuoteLine;
  }

  bool _isCatalogAt(
    int index,
    List<QuoteEditorLineBinding> bindings,
    QuoteLinesState state,
  ) {
    final QuoteEditorLineBinding binding = bindings[index];
    final Object line = state.lines[index];
    return binding.kind == QuoteEditorLineKind.catalog &&
        line is CatalogQuoteLine;
  }

  num _safeRate(num value) {
    if (value.isNaN || value.isInfinite || value < 0) {
      return 0;
    }
    return value;
  }

  String _safeName(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? 'Item' : trimmed;
  }

  Future<void> _editLineDialog(
    BuildContext context,
    WidgetRef ref,
    int index,
    List<QuoteEditorLineBinding> bindings,
    List<SalesDocLineVm> vmLines,
  ) async {
    final QuoteEditorLineBinding binding = bindings[index];
    final Object line = linesState.lines[index];

    final String initialName = vmLines[index].title.trim();
    final int initialQty = vmLines[index].qty.toInt();
    final String initialDesc = vmLines[index].subtitle ?? '';

    final num initialRate = switch (line) {
      final CatalogQuoteLine l => l.effectiveRate,
      final ManualQuoteLine l => l.rate,
      _ => 0,
    };

    final res = await SalesDocDialogs.editLine(
      context,
      initialName: initialName,
      initialDescription: initialDesc,
      initialQty: initialQty,
      initialRate: initialRate,
      enableRate: !isMemberScoped && requirePrices,
      enableName: !isMemberScoped,
      enableDescription: !isMemberScoped,
      enableQty: true,
    );

    if (res == null) return;

    final QuoteLinesController lc = _linesCtl(ref);

    if (binding.kind == QuoteEditorLineKind.catalog &&
        line is CatalogQuoteLine) {
      if (isMemberScoped) {
        lc.updateCatalogLine(line.tile, lineKey: binding.key, qty: res.qty);
        return;
      }

      lc.updateCatalogLine(
        line.tile,
        lineKey: binding.key,
        qty: res.qty,
        name: _safeName(res.name),
        description: res.description,
        rate: requirePrices ? _safeRate(res.rate) : line.effectiveRate,
      );
      return;
    }

    if (binding.kind == QuoteEditorLineKind.manual && line is ManualQuoteLine) {
      if (isMemberScoped) {
        lc.updateManualLine(binding.manualId!, qty: res.qty);
        return;
      }

      lc.updateManualLine(
        binding.manualId!,
        name: _safeName(res.name),
        description: res.description,
        qty: res.qty,
        rate: requirePrices ? _safeRate(res.rate) : line.rate,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (linesState.lines.isEmpty) {
      return const Center(child: Text('No items yet. Add from Catalog below.'));
    }

    final List<QuoteEditorLineBinding> bindings = buildQuoteLineBindings(
      linesState,
    );
    final List<SalesDocLineVm> vmLines = buildQuoteLineVms(
      linesState,
      requirePrices: requirePrices,
    );

    final bool canEditLineDetails = !isMemberScoped;
    final bool canEditLineRate = !isMemberScoped && requirePrices;

    return SalesDocLinesList(
      currencyCode: currencyCode,
      lines: vmLines,
      mode: SalesDocMode.edit,
      onEditName: (!canEditLineDetails || busy)
          ? null
          : (int index, String nextName) async {
              final QuoteLinesController lc = _linesCtl(ref);

              if (_isManualAt(index, bindings, linesState)) {
                final QuoteEditorLineBinding binding = bindings[index];
                lc.updateManualLine(
                  binding.manualId!,
                  name: _safeName(nextName),
                );
                return;
              }

              if (_isCatalogAt(index, bindings, linesState)) {
                final QuoteEditorLineBinding binding = bindings[index];
                final CatalogQuoteLine line =
                    linesState.lines[index] as CatalogQuoteLine;

                lc.updateCatalogLine(
                  line.tile,
                  lineKey: binding.key,
                  name: _safeName(nextName),
                );
              }
            },
      onEditQtyRate: busy
          ? null
          : (int index, int nextQty, num nextRate) async {
              final QuoteLinesController lc = _linesCtl(ref);
              final int qty = nextQty;

              if (_isCatalogAt(index, bindings, linesState)) {
                final QuoteEditorLineBinding binding = bindings[index];
                final CatalogQuoteLine line =
                    linesState.lines[index] as CatalogQuoteLine;

                if (isMemberScoped) {
                  lc.updateCatalogLine(
                    line.tile,
                    lineKey: binding.key,
                    qty: qty,
                  );
                  return;
                }

                if (canEditLineRate) {
                  lc.updateCatalogLine(
                    line.tile,
                    lineKey: binding.key,
                    qty: qty,
                    rate: _safeRate(nextRate),
                  );
                } else {
                  lc.updateCatalogLine(
                    line.tile,
                    lineKey: binding.key,
                    qty: qty,
                  );
                }
                return;
              }

              if (_isManualAt(index, bindings, linesState)) {
                final QuoteEditorLineBinding binding = bindings[index];
                final ManualQuoteLine line =
                    linesState.lines[index] as ManualQuoteLine;

                if (isMemberScoped) {
                  lc.updateManualLine(binding.manualId!, qty: qty);
                  return;
                }

                if (canEditLineRate) {
                  lc.updateManualLine(
                    binding.manualId!,
                    qty: qty,
                    rate: _safeRate(nextRate),
                  );
                } else {
                  lc.updateManualLine(
                    binding.manualId!,
                    qty: qty,
                    rate: line.rate,
                  );
                }
              }
            },
      onEditLine: busy
          ? null
          : (int index) async {
              await _editLineDialog(context, ref, index, bindings, vmLines);
            },
      onRemoveLine: busy
          ? null
          : (int index) async {
              final bool ok = await SalesDocDialogs.confirmDelete(
                context,
                thing: 'line item',
                message: 'Remove this item from the quote?',
              );
              if (!ok) return;

              final String key = bindings[index].key;
              _linesCtl(ref).removeByKey(key);
            },
    );
  }
}
