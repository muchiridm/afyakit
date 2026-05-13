// lib/features/retail/quotes/widgets/quote_detail_screen.dart
// UPDATED: dumb UI (delegates to QuoteActionController), capability-gated via AuthUserX

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';

import 'package:afyakit/features/retail/quotes/extensions/quote_action_enum.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_action_controller.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:afyakit/features/retail/quotes/providers/zoho_quote_provider.dart';

import 'package:afyakit/features/retail/shared/sales_doc/feedback.dart';
import 'package:afyakit/features/retail/shared/sales_doc/header.dart';
import 'package:afyakit/features/retail/shared/sales_doc/lines.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:afyakit/features/retail/shared/sales_doc/status.dart';
import 'package:afyakit/features/retail/shared/sales_doc/totals.dart';

import 'package:afyakit/shared/layout/app_page.dart';

import 'package:afyakit/features/retail/quotes/widgets/quote_editor_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuoteDetailScreen extends ConsumerStatefulWidget {
  const QuoteDetailScreen({super.key, required this.quoteId});

  final String quoteId;

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
    final res = await Navigator.of(context).push<QuoteEditorResult>(
      MaterialPageRoute(
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

  @override
  Widget build(BuildContext context) {
    final quoteId = widget.quoteId.trim();

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

    final quoteAsync = ref.watch(zohoQuoteProvider(quoteId));
    final me = ref.watch(currentUserProvider).valueOrNull;

    final canManage = me?.canManageQuotes ?? false;

    final actionsCtl = ref.read(quoteActionControllerProvider);

    return AppPage(
      title: 'Quote',
      showBack: true,
      scrollable: false,
      actions: _buildActions(
        context,
        quoteAsync: quoteAsync,
        actionsCtl: actionsCtl,
        canManage: canManage,
        quoteId: quoteId,
      ),
      body: _buildBody(quoteAsync, actionsCtl: actionsCtl, quoteId: quoteId),
    );
  }

  Widget _buildBody(
    AsyncValue<ZohoQuote> quoteAsync, {
    required QuoteActionController actionsCtl,
    required String quoteId,
  }) {
    return quoteAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => SalesDocErrorState(
        title: 'Failed to load quote',
        message: e.toString(),
      ),
      data: (q) => RefreshIndicator(
        onRefresh: () => actionsCtl.refresh(quoteId),
        child: _buildDetail(q),
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context, {
    required AsyncValue<ZohoQuote> quoteAsync,
    required QuoteActionController actionsCtl,
    required bool canManage,
    required String quoteId,
  }) {
    final quote = quoteAsync.valueOrNull;
    final hasInsuranceContext = quote?.hasInsuranceContext == true;

    final actions = <Widget>[
      IconButton(
        tooltip: _acting ? 'Working…' : 'PDF',
        icon: const Icon(Icons.picture_as_pdf_outlined),
        onPressed: _acting
            ? null
            : () => _run(() => actionsCtl.viewPdf(context, quoteId: quoteId)),
      ),
    ];

    if (!canManage) return actions;

    actions.addAll([
      PopupMenuButton<QuoteAction>(
        tooltip: 'Actions',
        enabled: !_acting,
        onSelected: (a) {
          switch (a) {
            case QuoteAction.send:
              _run(() => actionsCtl.sendQuote(context, quoteId: quoteId));
              break;
            case QuoteAction.markSent:
              _run(() => actionsCtl.markSent(context, quoteId: quoteId));
              break;
            case QuoteAction.invoice:
              _run(
                () => actionsCtl.convertToInvoice(context, quoteId: quoteId),
              );
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: QuoteAction.send,
            child: Text('Send quote'),
          ),
          const PopupMenuItem(
            value: QuoteAction.markSent,
            child: Text('Mark as sent'),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: QuoteAction.invoice,
            child: Text(
              hasInsuranceContext
                  ? 'Convert to invoice + claim'
                  : 'Convert to invoice',
            ),
          ),
        ],
        icon: const Icon(Icons.more_vert),
      ),
      IconButton(
        tooltip: 'Edit quote',
        icon: const Icon(Icons.edit_outlined),
        onPressed: _acting ? null : () => _editQuote(context, quoteId: quoteId),
      ),
    ]);

    return actions;
  }

  Widget _buildDetail(ZohoQuote q) {
    final meta = _buildMeta(q);
    final currency = _currency(meta.currencyCode);
    final lines = _buildLines(q);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (_acting) const LinearProgressIndicator(minHeight: 2),
        SalesDocHeader(
          title: '',
          meta: meta,
          showStatus: false,
          trailing: _HeaderStatusPill(status: meta.status),
        ),
        if (q.hasPatientContext || q.hasInsuranceContext) ...[
          const Divider(height: 1),
          _PatientInsuranceCard(q: q),
        ],
        if (q.deliveryAddress != null && q.deliveryAddress!.isUsable) ...[
          const Divider(height: 1),
          _DeliveryAddressCard(q: q),
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

  static SalesDocMetaVm _buildMeta(ZohoQuote q) {
    final party = q.customerName.trim().isEmpty ? 'Customer' : q.customerName;

    final docNo = _bestDocNumber(q);

    final currency = (q.currencyCode ?? '').trim();

    return SalesDocMetaVm(
      partyName: party,
      docNumberOrId: docNo,
      status: q.status.trim(),
      currencyCode: currency,
      total: q.total,
      date: q.date,
      expiryDate: q.expiryDate,
    );
  }

  static String _bestDocNumber(ZohoQuote q) {
    final acc = (q.accountNumber ?? '').trim();
    if (acc.isNotEmpty) return acc;

    final id = q.quoteId.trim();
    return id.isEmpty ? '-' : id;
  }

  static List<SalesDocLineVm> _buildLines(ZohoQuote q) {
    return q.lineItems
        .map(
          (li) => SalesDocLineVm(
            title: _lineTitle(li),
            subtitle: _lineSubtitle(li),
            qty: li.quantity,
            rate: li.rate,
          ),
        )
        .toList(growable: false);
  }

  static String _currency(String code) {
    final c = code.trim();
    return c.isEmpty ? 'KES' : c;
  }

  static String _lineTitle(ZohoQuoteLineItem li) {
    final name = _cleanZohoLineText(li.name);
    final v = (name ?? '').trim();

    return v.isEmpty ? 'Item' : v;
  }

  static String? _lineSubtitle(ZohoQuoteLineItem li) {
    final desc = _cleanZohoLineText(li.description);
    final v = (desc ?? '').trim();

    return v.isEmpty ? null : v;
  }

  static String? _cleanZohoLineText(Object? v) {
    final t = (v ?? '').toString().trim();

    if (t.isEmpty) return null;
    if (t.toLowerCase() == 'item') return null;

    return t;
  }
}

class _PatientInsuranceCard extends StatelessWidget {
  const _PatientInsuranceCard({required this.q});

  final ZohoQuote q;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final patient = q.patientSnapshot;

    final patientName = (patient?.fullName ?? '').trim();
    final patientNo = (patient?.patientNo ?? '').trim();
    final relationship = (patient?.relationship ?? '').trim();

    final payerName = (patient?.payerName ?? '').trim();
    final memberNo = (patient?.memberNo ?? '').trim();
    final scheme = (patient?.scheme ?? '').trim();
    final membershipId = (q.resolvedMembershipId ?? '').trim();

    final hasPatient = patientName.isNotEmpty || patientNo.isNotEmpty;
    final hasInsurance =
        payerName.isNotEmpty ||
        memberNo.isNotEmpty ||
        scheme.isNotEmpty ||
        membershipId.isNotEmpty;

    if (!hasPatient && !hasInsurance) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        children: [
          if (hasPatient)
            _InfoBlock(
              icon: Icons.person_outline,
              title: 'Patient',
              primary: patientName.isNotEmpty ? patientName : patientNo,
              secondary: _joinClean([
                if (patientNo.isNotEmpty && patientName.isNotEmpty) patientNo,
                if (relationship.isNotEmpty) relationship,
              ]),
            ),
          if (hasInsurance)
            _InfoBlock(
              icon: Icons.health_and_safety_outlined,
              title: 'Insurance',
              primary: payerName.isNotEmpty ? payerName : 'Insurance claim',
              secondary: _joinClean([
                if (memberNo.isNotEmpty) 'Member $memberNo',
                if (scheme.isNotEmpty) scheme,
              ]),
            ),
        ],
      ),
    );
  }

  static String _joinClean(List<String> parts) {
    return parts.map((e) => e.trim()).where((e) => e.isNotEmpty).join(' · ');
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.primary,
    required this.secondary,
  });

  final IconData icon;
  final String title;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(primary, style: theme.textTheme.bodyMedium),
                if (secondary.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(secondary, style: theme.textTheme.bodySmall),
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
    final a = q.deliveryAddress!;
    final theme = Theme.of(context);

    final recipient = a.recipientDisplay.trim();
    final singleLine = a.singleLine.trim();
    final label = (a.label ?? '').trim();
    final placeName = (a.placeName ?? '').trim();

    final helperParts = <String>[
      if (label.isNotEmpty) label,
      if (placeName.isNotEmpty && placeName != label) placeName,
    ];

    final helper = helperParts.join(' • ').trim();

    final showCoordsOnly = singleLine.isEmpty && a.hasCoordinates;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
          if (helper.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(helper, style: theme.textTheme.bodySmall),
          ],
          if (showCoordsOnly) ...[
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
    final s = status.trim();
    if (s.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SalesDocLeadingIcon(status: s, radius: 14),
        const SizedBox(width: 8),
        SalesDocStatusChip(status: s),
      ],
    );
  }
}
