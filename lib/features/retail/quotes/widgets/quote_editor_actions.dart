// lib/features/retail/sales/quotes/widgets/quote_editor_actions.dart

import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/retail/contacts/widgets/contact_picker_dialog.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/shared/models/zoho_contact.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:afyakit/features/retail/shared/sales_doc/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuoteEditorHeaderActions extends StatelessWidget {
  const QuoteEditorHeaderActions({
    super.key,
    required this.isEdit,
    required this.busy,
    required this.meta,
    required this.vmMeta,
    required this.isMemberScoped,
    required this.onContactPicked,
    required this.onDelete,
    required this.onEnsureAuthed,
  });

  static const double _kTrailH = 36;

  final bool isEdit;
  final bool busy;
  final QuoteMetaState meta;
  final SalesDocMetaVm vmMeta;
  final bool isMemberScoped;
  final ValueChanged<ZohoContact> onContactPicked;
  final Future<void> Function() onDelete;
  final Future<bool> Function() onEnsureAuthed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final ButtonStyle pickStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, _kTrailH),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final ButtonStyle iconStyle = IconButton.styleFrom(
      minimumSize: const Size(_kTrailH, _kTrailH),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final bool hasContact = meta.contact != null;

    Future<void> pickContact() async {
      final bool ok = await onEnsureAuthed();
      if (!ok) return;
      if (!context.mounted) return;

      final ZohoContact? picked = await showDialog<ZohoContact>(
        context: context,
        builder: (_) => const ContactPickerDialog(),
      );

      if (picked == null) return;
      onContactPicked(picked);
    }

    return SizedBox(
      height: _kTrailH,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SalesDocStatusChip(
            status: vmMeta.status,
            visualDensity: VisualDensity.compact,
            forceLabel: isEdit ? 'editing' : 'draft',
          ),
          if (!isMemberScoped) ...<Widget>[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: pickStyle,
              icon: const Icon(Icons.person_outline, size: 18),
              label: Text(hasContact ? 'Change' : 'Pick'),
              onPressed: busy ? null : pickContact,
            ),
          ],
          if (isEdit) ...<Widget>[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Delete quote',
              style: iconStyle,
              icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
              onPressed: busy ? null : onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

class QuoteEditorFooterBar extends ConsumerWidget {
  const QuoteEditorFooterBar({
    super.key,
    required this.busy,
    required this.isEdit,
    required this.meta,
    required this.linesState,
    required this.requirePrices,
    required this.isMemberScoped,
    required this.currencyCode,
    required this.onEnsureAuthed,
    required this.onSubmit,
  });

  final bool busy;
  final bool isEdit;
  final QuoteMetaState meta;
  final QuoteLinesState linesState;
  final bool requirePrices;
  final bool isMemberScoped;
  final String currencyCode;
  final Future<bool> Function() onEnsureAuthed;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bool canSubmit =
        linesState.lines.isNotEmpty &&
        (!requirePrices || linesState.hasAllPrices) &&
        (!isMemberScoped || meta.contact != null);

    Future<void> openCatalog() async {
      final bool ok = await onEnsureAuthed();
      if (!ok) return;
      if (!context.mounted) return;

      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const CatalogScreen()));
    }

    final String amountText = requirePrices
        ? '$currencyCode ${linesState.estimatedTotal.toStringAsFixed(2)}'
        : '—';

    final Widget addButton = OutlinedButton.icon(
      icon: const Icon(Icons.search),
      label: const Text('Add from Catalog'),
      onPressed: busy ? null : openCatalog,
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary),
      ),
    );

    final Widget submitButton = FilledButton.icon(
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(isEdit ? Icons.save : Icons.send),
      label: Text(
        busy ? 'Submitting…' : (isEdit ? 'Save changes' : 'Request a quote'),
      ),
      onPressed: (!canSubmit || busy) ? null : onSubmit,
    );

    final Widget totalBlock = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wideEnough = constraints.maxWidth > 220;

        if (wideEnough) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Estimated total',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amountText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              'Estimated total',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              amountText,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide = constraints.maxWidth >= 720;

              if (wide) {
                return Row(
                  children: <Widget>[
                    addButton,
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: submitButton,
                        ),
                      ),
                    ),
                    totalBlock,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(children: <Widget>[const Spacer(), totalBlock]),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(child: addButton),
                      const SizedBox(width: 12),
                      Expanded(child: submitButton),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
