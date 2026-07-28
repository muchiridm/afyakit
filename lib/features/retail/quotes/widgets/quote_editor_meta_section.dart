// lib/features/retail/sales/quotes/widgets/quote_editor_meta_section.dart

import 'package:afyakit/features/delivery_addresses/models/delivery_address.dart';
import 'package:afyakit/features/delivery_addresses/widgets/delivery_addresses_screen.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/date_pill.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:flutter/material.dart';

String quoteCurrencyCode() => 'KES';

DateTime quoteDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

Future<DateTime?> pickQuoteEditorDate(
  BuildContext context, {
  required DateTime initial,
  DateTime? firstDate,
  DateTime? lastDate,
  required String helpText,
}) async {
  final DateTime now = DateTime.now();

  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: firstDate ?? DateTime(now.year - 5, 1, 1),
    lastDate: lastDate ?? DateTime(now.year + 10, 12, 31),
    helpText: helpText,
  );

  return picked == null ? null : quoteDateOnly(picked);
}

Future<void> pickQuoteDeliveryAddress(
  BuildContext context, {
  required Future<bool> Function() ensureAuthed,
  required QuoteMetaController metaCtl,
}) async {
  final bool ok = await ensureAuthed();
  if (!ok) return;
  if (!context.mounted) return;

  final DeliveryAddress? result = await Navigator.of(context)
      .push<DeliveryAddress>(
        MaterialPageRoute<DeliveryAddress>(
          builder: (_) => const DeliveryAddressesScreen(pickerMode: true),
        ),
      );

  if (result == null) return;

  metaCtl.setDeliveryAddress(SalesDocumentAddress.fromDeliveryAddress(result));
}

SalesDocMetaVm buildQuoteMetaVm({
  required QuoteMetaState meta,
  required QuoteLinesState linesState,
  required bool isEdit,
  required bool requirePrices,
  required String fallbackPartyName,
}) {
  final String contactTitle = (meta.contact?.title ?? '').trim();

  final String fb = fallbackPartyName.trim();
  final String partyName = contactTitle.isNotEmpty
      ? contactTitle
      : (fb.isNotEmpty ? fb : 'Customer');

  final String docNo = isEdit
      ? ((meta.editingQuoteId ?? '').trim().isEmpty
            ? '-'
            : (meta.editingQuoteId ?? '').trim())
      : '';

  return SalesDocMetaVm(
    partyName: partyName,
    docNumberOrId: docNo,
    status: isEdit ? 'editing' : 'draft',
    currencyCode: quoteCurrencyCode(),
    total: requirePrices ? linesState.estimatedTotal : 0,
    date: meta.quoteDate,
    expiryDate: meta.expiryDate,
  );
}

class QuoteEditorMetaSection extends StatelessWidget {
  const QuoteEditorMetaSection({
    super.key,
    required this.busy,
    required this.meta,
    required this.metaCtl,
    required this.refController,
    required this.notesController,
    required this.onEnsureAuthed,
  });

  final bool busy;
  final QuoteMetaState meta;
  final QuoteMetaController metaCtl;
  final TextEditingController refController;
  final TextEditingController notesController;
  final Future<bool> Function() onEnsureAuthed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final DateTime? qd = meta.quoteDate;
    final DateTime? ed = meta.expiryDate;
    final SalesDocumentAddress? addr = meta.deliveryAddress;

    final DateTime now = DateTime.now();
    final DateTime initialQuoteDate = qd ?? quoteDateOnly(now);
    final DateTime initialExpiryDate =
        ed ??
        (qd == null
            ? quoteDateOnly(now.add(const Duration(days: 30)))
            : quoteDateOnly(qd.add(const Duration(days: 30))));

    Future<void> pickQuoteDate() async {
      final DateTime? picked = await pickQuoteEditorDate(
        context,
        initial: initialQuoteDate,
        helpText: 'Select quote date',
      );
      if (picked == null) return;

      metaCtl.setQuoteDate(picked);

      final DateTime? currentExpiry = meta.expiryDate;
      if (currentExpiry == null) {
        metaCtl.setExpiryDate(
          quoteDateOnly(picked.add(const Duration(days: 30))),
        );
      }
    }

    Future<void> pickExpiryDate() async {
      final DateTime base = meta.quoteDate ?? quoteDateOnly(DateTime.now());

      final DateTime? picked = await pickQuoteEditorDate(
        context,
        initial: initialExpiryDate,
        firstDate: base,
        helpText: 'Select expiry date',
      );
      if (picked == null) return;

      metaCtl.setExpiryDate(picked);
    }

    String cleanJoin(List<String?> parts, {String sep = ' • '}) {
      return parts
          .map((e) => (e ?? '').trim())
          .where((e) => e.isNotEmpty)
          .join(sep)
          .trim();
    }

    final String addressTitleFull = (addr?.singleLine ?? '').trim().isNotEmpty
        ? addr!.singleLine.trim()
        : 'Select delivery address';

    final String addressTitleShort =
        (addr?.shortDisplay ?? '').trim().isNotEmpty
        ? addr!.shortDisplay.trim()
        : addressTitleFull;

    final String addressSubtitle = cleanJoin(<String?>[
      addr?.recipientName,
      addr?.recipientPhone,
    ]);

    final String addressDetails = cleanJoin(<String?>[
      addr?.recipientDisplay,
      addr?.label,
      addr?.line1,
      addr?.line2,
      addr?.area,
      addr?.city,
      addr?.county,
      addr?.landmark == null || addr!.landmark!.trim().isEmpty
          ? null
          : 'Near ${addr.landmark!.trim()}',
      addr?.instructions,
      addr?.placeName,
    ], sep: '\n');

    Future<void> showFullAddress() async {
      if (addr == null) {
        await pickQuoteDeliveryAddress(
          context,
          ensureAuthed: onEnsureAuthed,
          metaCtl: metaCtl,
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Delivery address'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(addressTitleFull, style: theme.textTheme.bodyLarge),
                  if (addressSubtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(addressSubtitle, style: theme.textTheme.bodyMedium),
                  ],
                  if (addressDetails.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(addressDetails, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await pickQuoteDeliveryAddress(
                    context,
                    ensureAuthed: onEnsureAuthed,
                    metaCtl: metaCtl,
                  );
                },
                child: Text('Change'),
              ),
            ],
          );
        },
      );
    }

    InputDecoration denseDecoration({
      required String labelText,
      String? hintText,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        isDense: true,
        labelText: labelText,
        hintText: hintText,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      );
    }

    final Widget referenceField = TextField(
      controller: refController,
      enabled: !busy,
      style: theme.textTheme.bodyMedium,
      decoration: denseDecoration(
        labelText: 'Reference',
        hintText: 'e.g. PO number',
      ),
      onChanged: metaCtl.setReference,
    );

    final Widget notesField = TextField(
      controller: notesController,
      enabled: !busy,
      minLines: 1,
      maxLines: 2,
      style: theme.textTheme.bodyMedium,
      decoration: denseDecoration(
        labelText: 'Customer notes',
        hintText: 'Notes on the quote…',
      ),
      onChanged: metaCtl.setCustomerNotes,
    );

    final Widget addressField = InkWell(
      onTap: busy ? null : showFullAddress,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: denseDecoration(
          labelText: 'Delivery address',
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (addr != null)
                IconButton(
                  tooltip: 'Clear delivery address',
                  visualDensity: VisualDensity.compact,
                  onPressed: busy ? null : metaCtl.clearDeliveryAddress,
                  icon: const Icon(Icons.close, size: 18),
                ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.chevron_right, size: 18),
              ),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Tooltip(
              message: addressTitleFull,
              child: Text(
                addressTitleShort,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (addressSubtitle.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Tooltip(
                message: addressSubtitle,
                child: Text(
                  addressSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 860;

        if (isWide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Column(
                    children: <Widget>[
                      SalesDocDatePill(
                        label: 'Date',
                        icon: Icons.event_outlined,
                        date: qd,
                        enabled: !busy,
                        onPick: busy ? null : pickQuoteDate,
                        onClear: busy ? null : () => metaCtl.clearQuoteDate(),
                      ),
                      const SizedBox(height: 6),
                      SalesDocDatePill(
                        label: 'Expiry',
                        icon: Icons.timelapse_outlined,
                        date: ed,
                        enabled: !busy,
                        onPick: busy ? null : pickExpiryDate,
                        onClear: busy ? null : () => metaCtl.clearExpiryDate(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(child: referenceField),
                          const SizedBox(width: 8),
                          Expanded(child: notesField),
                        ],
                      ),
                      const SizedBox(height: 6),
                      addressField,
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: SalesDocDatePill(
                      label: 'Date',
                      icon: Icons.event_outlined,
                      date: qd,
                      enabled: !busy,
                      onPick: busy ? null : pickQuoteDate,
                      onClear: busy ? null : () => metaCtl.clearQuoteDate(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SalesDocDatePill(
                      label: 'Expiry',
                      icon: Icons.timelapse_outlined,
                      date: ed,
                      enabled: !busy,
                      onPick: busy ? null : pickExpiryDate,
                      onClear: busy ? null : () => metaCtl.clearExpiryDate(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              addressField,
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(child: referenceField),
                  const SizedBox(width: 8),
                  Expanded(child: notesField),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
