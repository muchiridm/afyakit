// lib/features/retail/quotes/widgets/quote_detail_screen.dart

import 'package:afyakit/features/retail/quotes/controllers/quote_action_controller.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:afyakit/features/retail/quotes/providers/zoho_quote_provider.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_detail_permissions.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_editor_screen.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';

import 'package:afyakit/features/retail/shared/sales_doc/feedback.dart';
import 'package:afyakit/features/retail/shared/sales_doc/header.dart';
import 'package:afyakit/features/retail/shared/sales_doc/lines.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:afyakit/features/retail/shared/sales_doc/status.dart';
import 'package:afyakit/features/retail/shared/sales_doc/totals.dart';

import 'package:afyakit/shared/layout/app_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuoteDetailScreen extends ConsumerStatefulWidget {
  const QuoteDetailScreen({
    super.key,
    required this.quoteId,
    this.forceStaffWorkspace,
  });

  final String quoteId;

  /// When null, the screen falls back to isStaffWorkspaceActiveProvider.
  /// When true/false, callers can explicitly decide staff vs member mode.
  final bool? forceStaffWorkspace;

  @override
  ConsumerState<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends ConsumerState<QuoteDetailScreen> {
  bool _acting = false;

  Future<void> _run(Future<void> Function() fn) async {
    if (_acting) return;

    setState(() => _acting = true);

    try {
      await fn();
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _editQuote(
    BuildContext context, {
    required String quoteId,
  }) async {
    final QuoteEditorResult? res = await Navigator.of(context)
        .push<QuoteEditorResult>(
          MaterialPageRoute<QuoteEditorResult>(
            builder: (_) => QuoteEditorScreen(editingQuoteId: quoteId),
          ),
        );

    if (!mounted) return;

    if (res == QuoteEditorResult.deleted) {
      Navigator.of(context).pop(true);
      return;
    }

    if (res == QuoteEditorResult.saved) {
      ref.invalidate(zohoQuoteProvider(quoteId));
    }
  }

  Future<void> _deleteDraft(
    BuildContext context, {
    required QuoteActionController actionsCtl,
    required String quoteId,
    required bool forceStaffWorkspace,
  }) async {
    await _run(
      () => actionsCtl.deleteQuote(
        context,
        quoteId: quoteId,
        forceStaffWorkspace: forceStaffWorkspace,
      ),
    );

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final String quoteId = widget.quoteId.trim();

    if (quoteId.isEmpty) {
      return const AppPage(
        title: 'Quote',
        showBack: true,
        scrollable: false,
        body: SalesDocErrorState(
          title: 'Invalid quote',
          message: 'Missing quote id',
        ),
      );
    }

    final AsyncValue<ZohoQuote> quoteAsync = ref.watch(
      zohoQuoteProvider(quoteId),
    );

    final QuoteActionController actionsCtl = ref.read(
      quoteActionControllerProvider,
    );

    return quoteAsync.when(
      loading: () => const AppPage(
        title: 'Quote',
        showBack: true,
        scrollable: false,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, _) => AppPage(
        title: 'Quote',
        showBack: true,
        scrollable: false,
        body: SalesDocErrorState(
          title: 'Failed to load quote',
          message: e.toString(),
        ),
      ),
      data: (ZohoQuote quote) {
        final QuoteUiPermissions permissions = buildQuoteUiPermissions(
          ref,
          quote,
          forceStaffWorkspace: widget.forceStaffWorkspace,
        );

        return AppPage(
          title: 'Quote',
          showBack: true,
          scrollable: false,
          actions: _buildTopActions(
            context,
            actionsCtl: actionsCtl,
            permissions: permissions,
            quoteId: quoteId,
          ),
          body: RefreshIndicator(
            onRefresh: () => actionsCtl.refresh(quoteId),
            child: _buildDetail(quote),
          ),
        );
      },
    );
  }

  List<Widget> _buildTopActions(
    BuildContext context, {
    required QuoteActionController actionsCtl,
    required QuoteUiPermissions permissions,
    required String quoteId,
  }) {
    final List<Widget> actions = <Widget>[];
    final bool forceStaffWorkspace = permissions.isStaffWorkspaceActive;

    if (permissions.isDraft && permissions.canEdit) {
      actions.add(
        _TopBarActionButton(
          tooltip: permissions.isStaffWorkspaceActive
              ? 'Edit quote'
              : 'Edit request',
          icon: Icons.edit_outlined,
          label: 'Edit',
          onPressed: _acting
              ? null
              : () => _editQuote(context, quoteId: quoteId),
        ),
      );
    }

    if (permissions.isDraft && permissions.canSend) {
      actions.add(
        _TopBarActionButton(
          tooltip: 'Send quotation',
          icon: Icons.send_outlined,
          label: 'Send',
          onPressed: _acting
              ? null
              : () => _run(
                  () => actionsCtl.sendQuote(
                    context,
                    quoteId: quoteId,
                    forceStaffWorkspace: forceStaffWorkspace,
                  ),
                ),
        ),
      );
    }

    if (permissions.isDraft && permissions.canDelete) {
      actions.add(
        IconButton(
          tooltip: permissions.isStaffWorkspaceActive
              ? 'Delete draft quote'
              : 'Delete draft request',
          icon: const Icon(Icons.delete_outline),
          onPressed: _acting
              ? null
              : () => _deleteDraft(
                  context,
                  actionsCtl: actionsCtl,
                  quoteId: quoteId,
                  forceStaffWorkspace: forceStaffWorkspace,
                ),
        ),
      );
    }

    if (permissions.isDraft && permissions.canMarkSent) {
      actions.add(
        IconButton(
          tooltip: 'Mark as sent',
          icon: const Icon(Icons.done_all_outlined),
          onPressed: _acting
              ? null
              : () => _run(
                  () => actionsCtl.markSent(
                    context,
                    quoteId: quoteId,
                    forceStaffWorkspace: forceStaffWorkspace,
                  ),
                ),
        ),
      );
    }

    if (permissions.canConvertToInvoice) {
      actions.add(
        _TopBarActionButton(
          tooltip: 'Convert to invoice',
          icon: Icons.receipt_long_outlined,
          label: 'Invoice',
          onPressed: _acting
              ? null
              : () => _run(
                  () => actionsCtl.convertToInvoice(
                    context,
                    quoteId: quoteId,
                    forceStaffWorkspace: forceStaffWorkspace,
                  ),
                ),
        ),
      );
    }

    if (permissions.canViewPdf) {
      actions.add(
        IconButton(
          tooltip: _acting ? 'Working…' : 'PDF',
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: _acting
              ? null
              : () => _run(
                  () => actionsCtl.viewPdf(
                    context,
                    quoteId: quoteId,
                    forceStaffWorkspace: forceStaffWorkspace,
                  ),
                ),
        ),
      );
    }

    return actions;
  }

  Widget _buildDetail(ZohoQuote quote) {
    final SalesDocMetaVm meta = _buildMeta(quote);
    final String currency = _currency(meta.currencyCode);
    final List<SalesDocLineVm> lines = _buildLines(quote);

    final bool hasClinicalContext =
        quote.hasPatientContext ||
        quote.hasInsuranceContext ||
        _clean(quote.resolvedPrescriptionId) != null;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        if (_acting) const LinearProgressIndicator(minHeight: 2),
        SalesDocHeader(
          title: '',
          meta: meta,
          showStatus: false,
          trailing: _HeaderStatusPill(status: meta.status),
        ),
        if (_isDraftQuote(quote)) const _DraftEditHint(),
        if (hasClinicalContext) ...<Widget>[
          const Divider(height: 1),
          _PatientInsurancePrescriptionCard(q: quote),
        ],
        if (quote.deliveryAddress != null &&
            quote.deliveryAddress!.isUsable) ...<Widget>[
          const Divider(height: 1),
          _DeliveryAddressCard(q: quote),
        ],
        const Divider(height: 1),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: SalesDocLinesList(
            currencyCode: currency,
            lines: lines,
            mode: SalesDocMode.view,
          ),
        ),
        SalesDocTotalBar(
          label: 'Total',
          total: meta.total,
          currencyCode: currency,
        ),
      ],
    );
  }

  static bool _isDraftQuote(ZohoQuote quote) {
    final String status = quote.status.trim().toLowerCase();
    return status.isEmpty || status == 'draft';
  }

  static SalesDocMetaVm _buildMeta(ZohoQuote q) {
    final String party = q.customerName.trim().isEmpty
        ? 'Customer'
        : q.customerName;

    final String docNo = _bestDocNumber(q);
    final String currency = (q.currencyCode ?? '').trim();

    return SalesDocMetaVm(
      partyName: party,
      docNumberOrId: docNo,
      status: q.status.trim().isEmpty ? 'draft' : q.status.trim(),
      currencyCode: currency,
      total: q.total,
      date: q.date,
      expiryDate: q.expiryDate,
    );
  }

  static String _bestDocNumber(ZohoQuote q) {
    final String acc = (q.accountNumber ?? '').trim();
    if (acc.isNotEmpty) return acc;

    final String id = q.quoteId.trim();
    return id.isEmpty ? '-' : id;
  }

  static List<SalesDocLineVm> _buildLines(ZohoQuote q) {
    return q.lineItems
        .map(
          (ZohoQuoteLineItem line) => SalesDocLineVm(
            title: _lineTitle(line),
            subtitle: _lineSubtitle(line),
            qty: line.quantity,
            rate: line.rate,
          ),
        )
        .toList(growable: false);
  }

  static String _currency(String code) {
    final String c = code.trim();
    return c.isEmpty ? 'KES' : c;
  }

  static String _lineTitle(ZohoQuoteLineItem line) {
    final String? name = _cleanZohoLineText(line.name);
    final String value = (name ?? '').trim();

    return value.isEmpty ? 'Item' : value;
  }

  static String? _lineSubtitle(ZohoQuoteLineItem line) {
    final String? desc = _cleanZohoLineText(line.description);
    final String value = (desc ?? '').trim();

    return value.isEmpty ? null : value;
  }

  static String? _cleanZohoLineText(Object? value) {
    final String text = (value ?? '').toString().trim();

    if (text.isEmpty) return null;
    if (text.toLowerCase() == 'item') return null;

    return text;
  }
}

class _TopBarActionButton extends StatelessWidget {
  const _TopBarActionButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _DraftEditHint extends StatelessWidget {
  const _DraftEditHint();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: scheme.primaryContainer.withOpacity(0.35),
      child: Row(
        children: <Widget>[
          Icon(Icons.edit_note_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This quote is still a draft. It can still be edited.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientInsurancePrescriptionCard extends StatelessWidget {
  const _PatientInsurancePrescriptionCard({required this.q});

  final ZohoQuote q;

  @override
  Widget build(BuildContext context) {
    final SalesDocumentPatientSnapshot? patient = q.patientSnapshot;

    final String patientName = (patient?.fullName ?? '').trim();
    final String patientNo = (patient?.patientNo ?? '').trim();
    final String relationship = (patient?.relationship ?? '').trim();

    final String payerName = (patient?.payerName ?? '').trim();
    final String memberNo = (patient?.memberNo ?? '').trim();
    final String scheme = (patient?.scheme ?? '').trim();
    final String membershipId = (q.resolvedMembershipId ?? '').trim();

    final String prescriptionId = (q.resolvedPrescriptionId ?? '').trim();
    final bool hasPatient = patientName.isNotEmpty || patientNo.isNotEmpty;

    final bool hasInsurance =
        payerName.isNotEmpty ||
        memberNo.isNotEmpty ||
        scheme.isNotEmpty ||
        membershipId.isNotEmpty;

    final bool hasPrescription = prescriptionId.isNotEmpty;
    final bool shouldWarnMissingPrescription = hasInsurance && !hasPrescription;

    if (!hasPatient && !hasInsurance && !hasPrescription) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        children: <Widget>[
          if (hasPatient)
            _InfoBlock(
              icon: Icons.person_outline,
              title: 'Patient',
              primary: patientName.isNotEmpty ? patientName : patientNo,
              secondary: _joinClean(<String>[
                if (patientNo.isNotEmpty && patientName.isNotEmpty) patientNo,
                if (relationship.isNotEmpty) relationship,
              ]),
            ),
          if (hasInsurance)
            _InfoBlock(
              icon: Icons.health_and_safety_outlined,
              title: 'Insurance',
              primary: payerName.isNotEmpty ? payerName : 'Insurance claim',
              secondary: _joinClean(<String>[
                if (memberNo.isNotEmpty) 'Member $memberNo',
                if (scheme.isNotEmpty) scheme,
                if (membershipId.isNotEmpty) 'Membership linked',
              ]),
            ),
          _InfoBlock(
            icon: hasPrescription
                ? Icons.verified_outlined
                : Icons.warning_amber_outlined,
            title: 'Prescription',
            primary: hasPrescription
                ? 'Prescription linked'
                : 'No prescription linked',
            secondary: hasPrescription
                ? 'Rx ID: $prescriptionId'
                : shouldWarnMissingPrescription
                ? 'This insurance quote has no prescription_id returned by the API.'
                : 'Optional for this quote.',
            warning: shouldWarnMissingPrescription,
          ),
        ],
      ),
    );
  }

  static String _joinClean(List<String> parts) {
    return parts
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .join(' · ');
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.primary,
    required this.secondary,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String primary;
  final String secondary;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final Color iconColor = warning ? scheme.error : scheme.onSurfaceVariant;
    final Color textColor = warning ? scheme.error : scheme.onSurface;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  primary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: warning ? FontWeight.w700 : null,
                  ),
                ),
                if (secondary.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    secondary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: warning ? scheme.error : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryAddressCard extends StatelessWidget {
  const _DeliveryAddressCard({required this.q});

  final ZohoQuote q;

  @override
  Widget build(BuildContext context) {
    final SalesDocumentAddress a = q.deliveryAddress!;
    final ThemeData theme = Theme.of(context);

    final String recipient = a.recipientDisplay.trim();
    final String singleLine = a.singleLine.trim();
    final String label = (a.label ?? '').trim();
    final String placeName = (a.placeName ?? '').trim();

    final String helper = <String>[
      if (label.isNotEmpty) label,
      if (placeName.isNotEmpty && placeName != label) placeName,
    ].join(' • ').trim();

    final bool showCoordsOnly = singleLine.isEmpty && a.hasCoordinates;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                'Delivery address',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (recipient.isNotEmpty)
            Text(
              recipient,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          if (recipient.isNotEmpty && singleLine.isNotEmpty)
            const SizedBox(height: 6),
          if (singleLine.isNotEmpty)
            Text(singleLine, style: theme.textTheme.bodyMedium),
          if (helper.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(helper, style: theme.textTheme.bodySmall),
          ],
          if (showCoordsOnly) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Pinned map location available',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderStatusPill extends StatelessWidget {
  const _HeaderStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final String s = status.trim();
    if (s.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SalesDocLeadingIcon(status: s, radius: 14),
        const SizedBox(width: 8),
        SalesDocStatusChip(status: s),
      ],
    );
  }
}

String? _clean(String? value) {
  final String text = (value ?? '').trim();
  return text.isEmpty ? null : text;
}
