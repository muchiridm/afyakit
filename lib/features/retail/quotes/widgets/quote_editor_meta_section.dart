// lib/features/retail/quotes/widgets/quote_editor_meta_section.dart

import 'package:afyakit/features/delivery_addresses/models/delivery_address.dart';
import 'package:afyakit/features/delivery_addresses/widgets/delivery_addresses_screen.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_clinical_context_dialog.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/date_pill.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:flutter/material.dart';

String quoteCurrencyCode() => 'KES';

DateTime quoteDateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

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
    initialDate: quoteDateOnly(initial),
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

Future<void> pickQuoteClinicalContext(
  BuildContext context, {
  required Future<bool> Function() ensureAuthed,
  required QuoteMetaState meta,
  required QuoteMetaController metaCtl,
}) async {
  final bool ok = await ensureAuthed();
  if (!ok) return;
  if (!context.mounted) return;

  final QuoteClinicalContextSelection? selected =
      await showDialog<QuoteClinicalContextSelection>(
        context: context,
        builder: (_) => QuoteClinicalContextDialog(
          initialPatientId: meta.resolvedPatientId,
          initialMembershipId: meta.resolvedMembershipId,
          initialPrescriptionId: meta.resolvedPrescriptionId,
          initialPaymentContext: meta.effectivePaymentContext,
        ),
      );

  if (selected == null) return;

  metaCtl.setClinicalContext(
    patientSnapshot: selected.patientSnapshot,
    paymentContext: selected.paymentContext,
    membershipId: selected.membershipId,
    payerContact: selected.payerContact,
    prescription: selected.prescription,
    prescriptionId: selected.prescriptionId,
  );
}

SalesDocMetaVm buildQuoteMetaVm({
  required QuoteMetaState meta,
  required QuoteLinesState linesState,
  required bool isEdit,
  required bool requirePrices,
  required String fallbackPartyName,
}) {
  final String contactTitle = _clean(meta.contact?.title) ?? '';
  final String fallback = _clean(fallbackPartyName) ?? '';

  final String partyName = contactTitle.isNotEmpty
      ? contactTitle
      : (fallback.isNotEmpty ? fallback : 'Customer');

  final String editingId = _clean(meta.editingQuoteId) ?? '';

  return SalesDocMetaVm(
    partyName: partyName,
    docNumberOrId: isEdit ? (editingId.isEmpty ? '-' : editingId) : '',
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
    final DateTime quoteDate = meta.quoteDate ?? quoteDateOnly(DateTime.now());
    final DateTime expiryDate =
        meta.expiryDate ?? _defaultExpiry(meta.quoteDate);

    final Widget dateRow = _DateRow(
      busy: busy,
      quoteDate: meta.quoteDate,
      expiryDate: meta.expiryDate,
      initialQuoteDate: quoteDate,
      initialExpiryDate: expiryDate,
      onPickQuoteDate: () => _pickQuoteDate(context),
      onClearQuoteDate: metaCtl.clearQuoteDate,
      onPickExpiryDate: () => _pickExpiryDate(context),
      onClearExpiryDate: metaCtl.clearExpiryDate,
    );

    final Widget clinicalContextField = _ClinicalContextTile(
      busy: busy,
      meta: meta,
      requiredForSubmit: meta.requiresPatient,
      onPick: () => pickQuoteClinicalContext(
        context,
        ensureAuthed: onEnsureAuthed,
        meta: meta,
        metaCtl: metaCtl,
      ),
      onClear: meta.hasPatientContext ? metaCtl.clearPatientContext : null,
    );

    final Widget addressField = _DeliveryAddressTile(
      busy: busy,
      address: meta.deliveryAddress,
      requiredForSubmit: meta.requiresDeliveryAddress,
      onPick: () => pickQuoteDeliveryAddress(
        context,
        ensureAuthed: onEnsureAuthed,
        metaCtl: metaCtl,
      ),
      onClear: meta.deliveryAddress == null
          ? null
          : metaCtl.clearDeliveryAddress,
    );

    final Widget referenceField = _MetaTextField(
      controller: refController,
      enabled: !busy,
      labelText: 'Reference',
      hintText: 'e.g. PO number',
      onChanged: metaCtl.setReference,
    );

    final Widget notesField = _MetaTextField(
      controller: notesController,
      enabled: !busy,
      labelText: 'Customer notes',
      hintText: 'Notes on the quote…',
      minLines: 1,
      maxLines: 2,
      onChanged: metaCtl.setCustomerNotes,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 900;

        if (!isWide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Column(
              children: <Widget>[
                dateRow,
                const SizedBox(height: 6),
                clinicalContextField,
                const SizedBox(height: 6),
                addressField,
                const SizedBox(height: 6),
                referenceField,
                const SizedBox(height: 6),
                notesField,
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: clinicalContextField),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        dateRow,
                        const SizedBox(height: 6),
                        addressField,
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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

  Future<void> _pickQuoteDate(BuildContext context) async {
    final DateTime initial = meta.quoteDate ?? quoteDateOnly(DateTime.now());

    final DateTime? picked = await pickQuoteEditorDate(
      context,
      initial: initial,
      helpText: 'Select quote date',
    );

    if (picked == null) return;

    metaCtl.setQuoteDate(picked);

    if (meta.expiryDate == null) {
      metaCtl.setExpiryDate(_defaultExpiry(picked));
    }
  }

  Future<void> _pickExpiryDate(BuildContext context) async {
    final DateTime base = meta.quoteDate ?? quoteDateOnly(DateTime.now());
    final DateTime initial = meta.expiryDate ?? _defaultExpiry(base);

    final DateTime? picked = await pickQuoteEditorDate(
      context,
      initial: initial,
      firstDate: base,
      helpText: 'Select expiry date',
    );

    if (picked == null) return;

    metaCtl.setExpiryDate(picked);
  }

  static DateTime _defaultExpiry(DateTime? quoteDate) {
    final DateTime base = quoteDate ?? quoteDateOnly(DateTime.now());
    return quoteDateOnly(base.add(const Duration(days: 30)));
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.busy,
    required this.quoteDate,
    required this.expiryDate,
    required this.initialQuoteDate,
    required this.initialExpiryDate,
    required this.onPickQuoteDate,
    required this.onClearQuoteDate,
    required this.onPickExpiryDate,
    required this.onClearExpiryDate,
  });

  final bool busy;
  final DateTime? quoteDate;
  final DateTime? expiryDate;
  final DateTime initialQuoteDate;
  final DateTime initialExpiryDate;
  final Future<void> Function() onPickQuoteDate;
  final VoidCallback onClearQuoteDate;
  final Future<void> Function() onPickExpiryDate;
  final VoidCallback onClearExpiryDate;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: _denseDecoration(labelText: 'Dates'),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SalesDocDatePill(
              label: 'Date *',
              icon: Icons.event_outlined,
              date: quoteDate,
              enabled: !busy,
              onPick: busy ? null : onPickQuoteDate,
              onClear: busy ? null : onClearQuoteDate,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SalesDocDatePill(
              label: 'Expiry',
              icon: Icons.timelapse_outlined,
              date: expiryDate,
              enabled: !busy,
              onPick: busy ? null : onPickExpiryDate,
              onClear: busy ? null : onClearExpiryDate,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTextField extends StatelessWidget {
  const _MetaTextField({
    required this.controller,
    required this.enabled,
    required this.labelText,
    required this.hintText,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final bool enabled;
  final String labelText;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      style: theme.textTheme.bodyMedium,
      decoration: _denseDecoration(labelText: labelText, hintText: hintText),
      onChanged: onChanged,
    );
  }
}

class _ClinicalContextTile extends StatelessWidget {
  const _ClinicalContextTile({
    required this.busy,
    required this.meta,
    required this.requiredForSubmit,
    required this.onPick,
    required this.onClear,
  });

  final bool busy;
  final QuoteMetaState meta;
  final bool requiredForSubmit;
  final Future<void> Function() onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final bool hasContext = meta.hasPatientContext;

    final String title = hasContext
        ? meta.patientLabel
        : 'Select clinical context';

    final String subtitle = hasContext
        ? _join(<String?>[
            meta.patientSubtitle,
            meta.paymentSubtitle,
            meta.isInsurancePayment ? meta.insuranceSubtitle : null,
            meta.prescriptionSubtitle == null
                ? null
                : 'Rx: ${meta.prescriptionSubtitle}',
          ], sep: '\n')
        : _emptySubtitle();

    return InkWell(
      onTap: busy ? null : onPick,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _denseDecoration(
          labelText: _labelText(hasContext),
          suffixIcon: _TileSuffixActions(busy: busy, onClear: onClear),
        ),
        child: _TileBody(
          icon: meta.isInsurancePayment
              ? Icons.health_and_safety_outlined
              : Icons.person_outline,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }

  String _labelText(bool hasContext) {
    if (!requiredForSubmit) return 'Clinical context optional';
    return 'Clinical context *';
  }

  String _emptySubtitle() {
    if (!requiredForSubmit) {
      return 'Optional for general sales.';
    }

    return 'Choose patient, payment context, insurance, and prescription in one place.';
  }
}

class _DeliveryAddressTile extends StatelessWidget {
  const _DeliveryAddressTile({
    required this.busy,
    required this.address,
    required this.requiredForSubmit,
    required this.onPick,
    required this.onClear,
  });

  final bool busy;
  final SalesDocumentAddress? address;
  final bool requiredForSubmit;
  final Future<void> Function() onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final String titleFull = _addressTitleFull(address);
    final String titleShort = _addressTitleShort(address, fallback: titleFull);
    final String subtitle = _addressSubtitle(address);
    final String details = _addressDetails(address);

    Future<void> showFullAddress() async {
      final SalesDocumentAddress? current = address;

      if (current == null) {
        await onPick();
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
                  Text(titleFull, style: theme.textTheme.bodyLarge),
                  if (subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                  if (details.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(details, style: theme.textTheme.bodySmall),
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
                  await onPick();
                },
                child: const Text('Change'),
              ),
            ],
          );
        },
      );
    }

    return InkWell(
      onTap: busy ? null : showFullAddress,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _denseDecoration(
          labelText: requiredForSubmit
              ? 'Delivery address *'
              : 'Delivery address optional',
          suffixIcon: _TileSuffixActions(busy: busy, onClear: onClear),
        ),
        child: _TileBody(
          icon: Icons.location_on_outlined,
          title: titleShort,
          titleTooltip: titleFull,
          subtitle: subtitle,
        ),
      ),
    );
  }

  static String _addressTitleFull(SalesDocumentAddress? address) {
    final String singleLine = _clean(address?.singleLine) ?? '';
    return singleLine.isNotEmpty ? singleLine : 'Select delivery address';
  }

  static String _addressTitleShort(
    SalesDocumentAddress? address, {
    required String fallback,
  }) {
    return _clean(address?.shortDisplay) ?? fallback;
  }

  static String _addressSubtitle(SalesDocumentAddress? address) {
    return _join(<String?>[address?.recipientName, address?.recipientPhone]);
  }

  static String _addressDetails(SalesDocumentAddress? address) {
    final String? landmark = _clean(address?.landmark);

    return _join(<String?>[
      address?.recipientDisplay,
      address?.label,
      address?.line1,
      address?.line2,
      address?.area,
      address?.city,
      address?.county,
      landmark == null ? null : 'Near $landmark',
      address?.instructions,
      address?.placeName,
    ], sep: '\n');
  }
}

class _TileBody extends StatelessWidget {
  const _TileBody({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleTooltip,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? titleTooltip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String cleanSubtitle = _clean(subtitle) ?? '';

    final Widget titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium,
    );

    return Row(
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if ((titleTooltip ?? '').trim().isNotEmpty)
                Tooltip(message: titleTooltip!, child: titleText)
              else
                titleText,
              if (cleanSubtitle.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  cleanSubtitle,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TileSuffixActions extends StatelessWidget {
  const _TileSuffixActions({required this.busy, required this.onClear});

  final bool busy;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (onClear != null)
          IconButton(
            tooltip: 'Clear',
            visualDensity: VisualDensity.compact,
            onPressed: busy ? null : onClear,
            icon: const Icon(Icons.close, size: 18),
          ),
        const Padding(
          padding: EdgeInsets.only(right: 10),
          child: Icon(Icons.chevron_right, size: 18),
        ),
      ],
    );
  }
}

InputDecoration _denseDecoration({
  required String labelText,
  String? hintText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    isDense: true,
    labelText: labelText,
    hintText: hintText,
    suffixIcon: suffixIcon,
    border: const OutlineInputBorder(),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

String? _clean(String? value) {
  final String text = (value ?? '').trim();
  return text.isEmpty ? null : text;
}

String _join(List<String?> parts, {String sep = ' • '}) {
  return parts
      .map((String? value) => (value ?? '').trim())
      .where((String value) => value.isNotEmpty)
      .join(sep)
      .trim();
}
