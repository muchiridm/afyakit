// lib/features/retail/quotes/widgets/quote_editor_actions.dart

import 'package:afyakit/features/retail/contacts/widgets/contact_picker_dialog.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/shared/sales_doc/dialogs.dart';
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

  static const double _trailHeight = 36;

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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final ButtonStyle pickStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, _trailHeight),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final ButtonStyle iconStyle = IconButton.styleFrom(
      minimumSize: const Size(_trailHeight, _trailHeight),
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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool tight =
            constraints.maxWidth > 0 && constraints.maxWidth < 260;

        final Widget statusChip = SalesDocStatusChip(
          status: vmMeta.status,
          visualDensity: VisualDensity.compact,
          forceLabel: tight ? null : (isEdit ? 'editing' : 'draft'),
        );

        final Widget? payerButton = isMemberScoped
            ? null
            : OutlinedButton.icon(
                style: pickStyle,
                icon: const Icon(Icons.person_outline, size: 18),
                label: Text(
                  hasContact ? 'Change payer' : 'Pick payer',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
                onPressed: busy ? null : pickContact,
              );

        final Widget? deleteButton = isEdit
            ? IconButton(
                tooltip: 'Delete quote',
                style: iconStyle,
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: colorScheme.error,
                ),
                onPressed: busy ? null : onDelete,
              )
            : null;

        final List<Widget> actions = <Widget>[
          statusChip,
          if (payerButton != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: tight ? 150 : 190),
              child: payerButton,
            ),
          if (deleteButton != null) deleteButton,
        ];

        return Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        );
      },
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

  String? _submitBlockReason() {
    if (busy) return null;

    if (linesState.lines.isEmpty) {
      return 'Add at least one item';
    }

    if (requirePrices && !linesState.hasAllPrices) {
      return 'Some items are missing prices';
    }

    if (meta.customerIdResolved.isEmpty) {
      return isMemberScoped
          ? 'Customer profile is still loading'
          : 'Pick a payer/customer';
    }

    if (meta.quoteDate == null) {
      return 'Select a quote date';
    }

    if (meta.requiresPatient && !meta.hasPatientContext) {
      return 'Select a patient profile';
    }

    if (meta.requiresDeliveryAddress && !meta.hasDeliveryAddress) {
      return 'Select a delivery address';
    }

    if (meta.requiresMembership && !meta.hasInsuranceContext) {
      return 'Select an insurance membership';
    }

    if (meta.isGeneral && meta.isInsurancePayment) {
      return 'Insurance payment requires a clinical quote';
    }

    return null;
  }

  String _safeName(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? 'Item' : trimmed;
  }

  num _safeRate(num value) {
    if (value.isNaN || value.isInfinite || value < 0) return 0;
    return value;
  }

  Future<void> _addCustomItem(BuildContext context, WidgetRef ref) async {
    final bool ok = await onEnsureAuthed();
    if (!ok) return;
    if (!context.mounted) return;

    final result = await SalesDocDialogs.editLine(
      context,
      initialName: '',
      initialDescription: '',
      initialQty: 1,
      initialRate: 0,
      enableRate: requirePrices,
      enableName: true,
      enableDescription: true,
      enableQty: true,
    );

    if (result == null) return;

    ref
        .read(quoteLinesControllerProvider.notifier)
        .addManualLine(
          name: _safeName(result.name),
          description: result.description,
          qty: result.qty,
          rate: requirePrices ? _safeRate(result.rate) : 0,
        );
  }

  Future<void> _addDeliveryCharge(BuildContext context, WidgetRef ref) async {
    final bool ok = await onEnsureAuthed();
    if (!ok) return;
    if (!context.mounted) return;

    final result = await SalesDocDialogs.editLine(
      context,
      initialName: kDeliveryChargeDefaultName,
      initialDescription: kDeliveryChargeDefaultDescription,
      initialQty: 1,
      initialRate: 0,
      enableRate: requirePrices,
      enableName: true,
      enableDescription: true,
      enableQty: true,
    );

    if (result == null) return;

    ref
        .read(quoteLinesControllerProvider.notifier)
        .addManualLine(
          name: _safeName(result.name),
          description: result.description,
          qty: result.qty,
          rate: requirePrices ? _safeRate(result.rate) : 0,
          zohoItemId: kZohoDeliveryServiceItemId,
        );
  }

  Widget _buttonText(String text) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      softWrap: false,
    );
  }

  ButtonStyle _compactButtonStyle() {
    return ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final String? submitBlockReason = _submitBlockReason();
    final bool canSubmit = submitBlockReason == null && !busy;

    final String amountText = requirePrices
        ? '$currencyCode ${linesState.estimatedTotal.toStringAsFixed(2)}'
        : '—';

    final ButtonStyle compactStyle = _compactButtonStyle();

    final Widget addCustomItemButton = OutlinedButton.icon(
      icon: const Icon(Icons.add_circle_outline),
      label: _buttonText('Custom item'),
      onPressed: (busy || isMemberScoped)
          ? null
          : () => _addCustomItem(context, ref),
      style: compactStyle,
    );

    final Widget addDeliveryChargeButton = OutlinedButton.icon(
      icon: const Icon(Icons.local_shipping_outlined),
      label: _buttonText('Delivery charge'),
      onPressed: (busy || isMemberScoped)
          ? null
          : () => _addDeliveryCharge(context, ref),
      style: compactStyle,
    );

    final Widget submitButton = Tooltip(
      message: submitBlockReason ?? '',
      child: FilledButton.icon(
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(isEdit ? Icons.save : Icons.send),
        label: _buttonText(
          busy ? 'Submitting…' : (isEdit ? 'Save' : 'Request quote'),
        ),
        onPressed: canSubmit ? onSubmit : null,
        style: compactStyle,
      ),
    );

    final Widget totalBlock = _EstimatedTotalBlock(amountText: amountText);

    final List<Widget> actionButtons = <Widget>[
      if (!isMemberScoped) ...<Widget>[
        addCustomItemButton,
        addDeliveryChargeButton,
      ],
    ];
    final bool hasActionButtons = actionButtons.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
              final bool wide = constraints.maxWidth >= 840;

              if (wide) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: <Widget>[
                    if (hasActionButtons)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: actionButtons,
                        ),
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 150,
                        maxWidth: 210,
                      ),
                      child: submitButton,
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 170,
                        maxWidth: 260,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: totalBlock,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: totalBlock,
                    ),
                  ),
                  if (hasActionButtons) ...<Widget>[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: actionButtons
                          .map(
                            (Widget button) => SizedBox(
                              width: constraints.maxWidth >= 520
                                  ? (constraints.maxWidth - 10) / 2
                                  : constraints.maxWidth,
                              child: button,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: submitButton),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EstimatedTotalBlock extends StatelessWidget {
  const _EstimatedTotalBlock({required this.amountText});

  final String amountText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
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
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 8),
              Text(
                amountText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Estimated total',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              amountText,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}
