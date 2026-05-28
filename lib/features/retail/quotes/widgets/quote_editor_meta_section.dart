// lib/features/retail/quotes/widgets/quote_editor_meta_section.dart

import 'package:afyakit/features/clinical/prescriptions/controllers/prescriptions_controller.dart';
import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/providers/prescriptions_providers.dart';
import 'package:afyakit/features/delivery_addresses/models/delivery_address.dart';
import 'package:afyakit/features/delivery_addresses/widgets/delivery_addresses_screen.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/quotes/models/quote_sale_context.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_patient_membership_picker_dialog.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/date_pill.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

Future<void> pickQuotePatientContext(
  BuildContext context, {
  required Future<bool> Function() ensureAuthed,
  required QuoteMetaState meta,
  required QuoteMetaController metaCtl,
}) async {
  final bool ok = await ensureAuthed();
  if (!ok) return;
  if (!context.mounted) return;

  final QuotePatientContextSelection? selected =
      await showDialog<QuotePatientContextSelection>(
        context: context,
        builder: (_) => QuotePatientMembershipPickerDialog(
          initialPatientId: meta.resolvedPatientId,
          initialMembershipId: meta.resolvedMembershipId,
          initialPaymentContext: meta.effectivePaymentContext,
        ),
      );

  if (selected == null) return;

  metaCtl.setPatientContext(
    patientSnapshot: selected.patientSnapshot,
    membershipId: selected.membershipId,
    payerContact: selected.payerContact,
    paymentContext: selected.paymentContext,
  );
}

Future<void> pickQuotePrescription(
  BuildContext context, {
  required List<Prescription> prescriptions,
  required String? selectedPrescriptionId,
  required bool requiredForClaim,
  required QuoteMetaController metaCtl,
}) async {
  final List<Prescription> active = prescriptions
      .where((Prescription p) => p.isActive)
      .toList(growable: false);

  final List<Prescription> selectable = requiredForClaim
      ? active
            .where((Prescription p) => p.status == PrescriptionStatus.verified)
            .toList(growable: false)
      : active;

  final Prescription? picked = await showDialog<Prescription>(
    context: context,
    builder: (BuildContext context) {
      return _PrescriptionPickerDialog(
        prescriptions: selectable,
        selectedPrescriptionId: selectedPrescriptionId,
        requiredForClaim: requiredForClaim,
      );
    },
  );

  if (picked == null) return;

  metaCtl.setPrescription(picked);
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

class QuoteEditorMetaSection extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime quoteDate = meta.quoteDate ?? quoteDateOnly(DateTime.now());
    final DateTime expiryDate =
        meta.expiryDate ?? _defaultExpiry(meta.quoteDate);

    final String patientId = (meta.resolvedPatientId ?? '').trim();

    final PrescriptionsState rxState = patientId.isEmpty
        ? const PrescriptionsState()
        : ref.watch(prescriptionPickerControllerProvider(patientId));

    final Widget saleAndPaymentSelector = _SaleAndPaymentSelector(
      busy: busy,
      meta: meta,
      onSaleChanged: metaCtl.setSaleContext,
      onPaymentChanged: metaCtl.setPaymentContext,
    );

    final Widget dateColumn = _DateColumn(
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

    final Widget referenceAndNotes = Row(
      children: <Widget>[
        Expanded(
          child: _MetaTextField(
            controller: refController,
            enabled: !busy,
            labelText: 'Reference',
            hintText: 'e.g. PO number',
            onChanged: metaCtl.setReference,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetaTextField(
            controller: notesController,
            enabled: !busy,
            labelText: 'Customer notes',
            hintText: 'Notes on the quote…',
            minLines: 1,
            maxLines: 2,
            onChanged: metaCtl.setCustomerNotes,
          ),
        ),
      ],
    );

    final Widget patientField = _PatientContextTile(
      busy: busy,
      meta: meta,
      requiredForSubmit: meta.requiresPatient,
      onPick: () => pickQuotePatientContext(
        context,
        ensureAuthed: onEnsureAuthed,
        meta: meta,
        metaCtl: metaCtl,
      ),
      onClear: meta.hasPatientContext ? metaCtl.clearPatientContext : null,
    );

    final Widget prescriptionField = _PrescriptionTile(
      busy: busy || rxState.busy,
      patientId: patientId,
      prescriptions: rxState.items,
      selectedPrescriptionId: meta.resolvedPrescriptionId,
      requiredForClaim: meta.isInsurancePayment,
      error: rxState.error,
      onPick: patientId.isEmpty
          ? null
          : () => pickQuotePrescription(
              context,
              prescriptions: rxState.items,
              selectedPrescriptionId: meta.resolvedPrescriptionId,
              requiredForClaim: meta.isInsurancePayment,
              metaCtl: metaCtl,
            ),
      onClear: (meta.resolvedPrescriptionId ?? '').trim().isEmpty
          ? null
          : metaCtl.clearPrescription,
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
                      saleAndPaymentSelector,
                      const SizedBox(height: 6),
                      dateColumn,
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: <Widget>[
                      referenceAndNotes,
                      const SizedBox(height: 6),
                      patientField,
                      const SizedBox(height: 6),
                      prescriptionField,
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
              saleAndPaymentSelector,
              const SizedBox(height: 6),
              dateColumn,
              const SizedBox(height: 6),
              patientField,
              const SizedBox(height: 6),
              prescriptionField,
              const SizedBox(height: 6),
              addressField,
              const SizedBox(height: 6),
              referenceAndNotes,
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

class _SaleAndPaymentSelector extends StatelessWidget {
  const _SaleAndPaymentSelector({
    required this.busy,
    required this.meta,
    required this.onSaleChanged,
    required this.onPaymentChanged,
  });

  final bool busy;
  final QuoteMetaState meta;
  final ValueChanged<QuoteSaleContext> onSaleChanged;
  final ValueChanged<QuotePaymentContext> onPaymentChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InputDecorator(
      decoration: _denseDecoration(labelText: 'Sale & payment'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SegmentedButton<QuoteSaleContext>(
            showSelectedIcon: false,
            style: _segmentedStyle(),
            segments: const <ButtonSegment<QuoteSaleContext>>[
              ButtonSegment<QuoteSaleContext>(
                value: QuoteSaleContext.clinical,
                icon: Icon(Icons.medical_services_outlined, size: 18),
                label: Text('Clinical'),
              ),
              ButtonSegment<QuoteSaleContext>(
                value: QuoteSaleContext.general,
                icon: Icon(Icons.storefront_outlined, size: 18),
                label: Text('General'),
              ),
            ],
            selected: <QuoteSaleContext>{meta.saleContext},
            onSelectionChanged: busy
                ? null
                : (Set<QuoteSaleContext> selected) {
                    onSaleChanged(selected.first);
                  },
          ),
          if (meta.isClinical) ...<Widget>[
            const SizedBox(height: 8),
            SegmentedButton<QuotePaymentContext>(
              showSelectedIcon: false,
              style: _segmentedStyle(),
              segments: const <ButtonSegment<QuotePaymentContext>>[
                ButtonSegment<QuotePaymentContext>(
                  value: QuotePaymentContext.directPay,
                  icon: Icon(Icons.payments_outlined, size: 18),
                  label: Text('Direct pay'),
                ),
                ButtonSegment<QuotePaymentContext>(
                  value: QuotePaymentContext.insurance,
                  icon: Icon(Icons.health_and_safety_outlined, size: 18),
                  label: Text('Insurance'),
                ),
              ],
              selected: <QuotePaymentContext>{meta.effectivePaymentContext},
              onSelectionChanged: busy
                  ? null
                  : (Set<QuotePaymentContext> selected) {
                      onPaymentChanged(selected.first);
                    },
            ),
          ],
          const SizedBox(height: 6),
          Text(_helperText(meta), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  static ButtonStyle _segmentedStyle() {
    return ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  static String _helperText(QuoteMetaState meta) {
    if (meta.isGeneral) {
      return 'OTC / B2B / general sale. Patient and delivery address are optional.';
    }

    if (meta.isInsurancePayment) {
      return 'Insurance sale. Patient, membership, prescription, and delivery address are required. Customer should be the insurer.';
    }

    return 'Direct-pay clinical sale. Patient and delivery address are required. Customer can be the patient, parent, guardian, company, or other payer.';
  }
}

class _DateColumn extends StatelessWidget {
  const _DateColumn({
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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool inline = constraints.maxWidth >= 420;

        final Widget quoteDatePill = SalesDocDatePill(
          label: 'Date *',
          icon: Icons.event_outlined,
          date: quoteDate,
          enabled: !busy,
          onPick: busy ? null : onPickQuoteDate,
          onClear: busy ? null : onClearQuoteDate,
        );

        final Widget expiryDatePill = SalesDocDatePill(
          label: 'Expiry',
          icon: Icons.timelapse_outlined,
          date: expiryDate,
          enabled: !busy,
          onPick: busy ? null : onPickExpiryDate,
          onClear: busy ? null : onClearExpiryDate,
        );

        if (inline) {
          return Row(
            children: <Widget>[
              Expanded(child: quoteDatePill),
              const SizedBox(width: 8),
              Expanded(child: expiryDatePill),
            ],
          );
        }

        return Column(
          children: <Widget>[
            quoteDatePill,
            const SizedBox(height: 6),
            expiryDatePill,
          ],
        );
      },
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

class _PatientContextTile extends StatelessWidget {
  const _PatientContextTile({
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

    final String title = hasContext ? meta.patientLabel : 'Select patient';
    final String subtitle = _join(<String?>[
      meta.patientSubtitle,
      meta.isInsurancePayment ? meta.insuranceSubtitle : null,
      meta.paymentSubtitle,
    ], sep: '\n');

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
    if (!requiredForSubmit) return 'Patient optional';

    if (meta.requiresMembership) {
      return hasContext ? 'Patient + insurance *' : 'Patient + insurance *';
    }

    return hasContext ? 'Patient context *' : 'Patient *';
  }
}

class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({
    required this.busy,
    required this.patientId,
    required this.prescriptions,
    required this.selectedPrescriptionId,
    required this.requiredForClaim,
    required this.error,
    required this.onPick,
    required this.onClear,
  });

  final bool busy;
  final String patientId;
  final List<Prescription> prescriptions;
  final String? selectedPrescriptionId;
  final bool requiredForClaim;
  final String? error;
  final Future<void> Function()? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final Prescription? selected = _selectedPrescription();

    final bool hasPatient = patientId.trim().isNotEmpty;
    final bool hasSelected = selected != null;

    final String title = !hasPatient
        ? 'Select patient first'
        : hasSelected
        ? _title(selected)
        : 'Select prescription';

    final String subtitle = !hasPatient
        ? 'Prescription belongs to a patient profile.'
        : hasSelected
        ? _subtitle(selected)
        : _emptySubtitle();

    return InkWell(
      onTap: busy || !hasPatient ? null : onPick,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _denseDecoration(
          labelText: requiredForClaim
              ? 'Prescription for claim *'
              : 'Prescription optional',
          suffixIcon: _TileSuffixActions(busy: busy, onClear: onClear),
        ),
        child: _TileBody(
          icon: Icons.description_outlined,
          title: title,
          subtitle: error == null ? subtitle : error,
        ),
      ),
    );
  }

  Prescription? _selectedPrescription() {
    final String id = (selectedPrescriptionId ?? '').trim();
    if (id.isEmpty) return null;

    for (final Prescription p in prescriptions) {
      if (p.prescriptionId == id) return p;
    }

    return null;
  }

  String _emptySubtitle() {
    if (requiredForClaim) {
      return 'Required before creating an insurance claim.';
    }

    return 'Optional for direct-pay quotes.';
  }

  static String _title(Prescription p) {
    final String fileName = p.fileName.trim();
    return fileName.isNotEmpty ? fileName : p.prescriptionId;
  }

  static String _subtitle(Prescription p) {
    return _join(<String?>[
      p.prescriptionId,
      p.prescribedOn == null ? null : 'Prescribed: ${p.prescribedOn}',
      p.status.label,
    ]);
  }
}

class _PrescriptionPickerDialog extends StatelessWidget {
  const _PrescriptionPickerDialog({
    required this.prescriptions,
    required this.selectedPrescriptionId,
    required this.requiredForClaim,
  });

  final List<Prescription> prescriptions;
  final String? selectedPrescriptionId;
  final bool requiredForClaim;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        requiredForClaim
            ? 'Select verified prescription'
            : 'Select prescription',
      ),
      content: SizedBox(
        width: 560,
        height: 420,
        child: prescriptions.isEmpty
            ? Center(
                child: Text(
                  requiredForClaim
                      ? 'No verified prescriptions found for this patient.'
                      : 'No active prescriptions found for this patient.',
                ),
              )
            : ListView.separated(
                itemCount: prescriptions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final Prescription p = prescriptions[index];
                  final bool selected =
                      p.prescriptionId == selectedPrescriptionId;

                  return ListTile(
                    leading: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.description_outlined,
                    ),
                    title: Text(
                      p.fileName.trim().isNotEmpty
                          ? p.fileName.trim()
                          : p.prescriptionId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _join(<String?>[
                        p.prescriptionId,
                        p.prescribedOn == null
                            ? null
                            : 'Prescribed: ${p.prescribedOn}',
                        p.status.label,
                      ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(context).pop(p),
                  );
                },
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
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
                  maxLines: 3,
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
