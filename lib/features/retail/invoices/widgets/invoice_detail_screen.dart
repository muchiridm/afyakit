// lib/features/retail/invoices/widgets/invoice_detail_screen.dart

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/workspace/providers/workspace_mode_provider.dart';
import 'package:afyakit/features/insurance/claim_packs/widgets/insurance_claim_detail_screen.dart';
import 'package:afyakit/features/retail/contacts/zoho_contact.dart';
import 'package:afyakit/features/retail/invoices/controllers/invoice_action_controller.dart';
import 'package:afyakit/features/retail/invoices/controllers/invoice_controller.dart';
import 'package:afyakit/features/retail/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/models/zoho_invoice_line_item.dart';
import 'package:afyakit/features/retail/payments/controllers/payment_controller.dart';
import 'package:afyakit/features/retail/payments/providers/payment_providers.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_footer.dart';
import 'package:afyakit/features/retail/shared/sales_doc/feedback.dart';
import 'package:afyakit/features/retail/shared/sales_doc/header.dart';
import 'package:afyakit/features/retail/shared/sales_doc/lines.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:afyakit/features/retail/shared/sales_doc/status.dart';
import 'package:afyakit/features/retail/shared/sales_doc/totals.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/utils/normalize/normalize_phone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _InvoiceMenuAction { send, markSent }

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailScreen> createState() {
    return _InvoiceDetailScreenState();
  }
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  static const double _contentMaxW = 720;

  bool _booted = false;
  bool _acting = false;

  String? _lastSeededPhone;
  num? _lastSeededPending;
  bool _seedScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_booted) return;
    _booted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await ref.read(invoiceControllerProvider.notifier).load(widget.invoiceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;

    final bool staffWorkspace = ref.watch(isStaffWorkspaceActiveProvider);

    final bool canManageInvoices =
        staffWorkspace && (me?.canManageInvoices ?? false);

    final InvoiceState state = ref.watch(invoiceControllerProvider);

    final InvoiceActionController actions = ref.read(
      invoiceActionControllerProvider,
    );

    final bool pdfBusy = _acting || state.downloadingPdf;
    final bool menuBusy = _acting || state.busy;

    return AppPage(
      title: 'Invoice',
      showBack: true,
      maxWidth: _contentMaxW,
      scrollable: true,
      actions: _buildActions(
        canManageInvoices: canManageInvoices,
        state: state,
        pdfBusy: pdfBusy,
        menuBusy: menuBusy,
        actions: actions,
      ),
      body: _buildBody(context, state, canManageInvoices: canManageInvoices),
      footer: null,
    );
  }

  List<Widget> _buildActions({
    required bool canManageInvoices,
    required InvoiceState state,
    required bool pdfBusy,
    required bool menuBusy,
    required InvoiceActionController actions,
  }) {
    return <Widget>[
      IconButton(
        tooltip: pdfBusy ? 'Working…' : 'PDF',
        onPressed: pdfBusy
            ? null
            : () => _runAction(
                () => actions.viewPdf(context, invoiceId: widget.invoiceId),
              ),
        icon: const Icon(Icons.picture_as_pdf_outlined),
      ),
      IconButton(
        tooltip: 'Refresh',
        onPressed: state.busy
            ? null
            : () => _runAction(() => actions.refresh(widget.invoiceId)),
        icon: const Icon(Icons.refresh),
      ),
      if (canManageInvoices)
        PopupMenuButton<_InvoiceMenuAction>(
          tooltip: 'More',
          enabled: !menuBusy,
          onSelected: (action) async {
            switch (action) {
              case _InvoiceMenuAction.send:
                await _runAction(
                  () =>
                      actions.sendInvoice(context, invoiceId: widget.invoiceId),
                );
                break;
              case _InvoiceMenuAction.markSent:
                await _runAction(
                  () => actions.markSent(context, invoiceId: widget.invoiceId),
                );
                break;
            }
          },
          itemBuilder: (_) => const <PopupMenuEntry<_InvoiceMenuAction>>[
            PopupMenuItem<_InvoiceMenuAction>(
              value: _InvoiceMenuAction.send,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.send_outlined),
                title: Text('Send invoice'),
              ),
            ),
            PopupMenuItem<_InvoiceMenuAction>(
              value: _InvoiceMenuAction.markSent,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.mark_email_read_outlined),
                title: Text('Mark as sent'),
              ),
            ),
          ],
          icon: const Icon(Icons.more_vert),
        ),
    ];
  }

  Widget _buildBody(
    BuildContext context,
    InvoiceState state, {
    required bool canManageInvoices,
  }) {
    if (state.loading && !state.hasInvoice) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!state.hasInvoice) {
      return SalesDocErrorState(
        title: 'Failed to load invoice',
        message: state.error ?? 'No invoice data',
      );
    }

    final ZohoInvoice invoice = state.invoice!;
    final _InvoiceVm vm = _buildVm(invoice);
    final String? suggestedPhone = _watchSuggestedPhone(invoice);

    _maybeSeedPaymentContext(
      invoiceId: invoice.invoiceId,
      pendingAmount: vm.pendingAmount,
      suggestedPhone: suggestedPhone,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_acting || state.busy) const LinearProgressIndicator(minHeight: 2),
        InlineErrorCard(message: (state.error ?? '').trim()),
        SalesDocHeader(
          title: 'Invoice',
          meta: vm.meta,
          showStatus: false,
          trailing: _HeaderStatusPill(status: vm.meta.status),
        ),
        const Divider(height: 1),
        if (invoice.isInsurancePayment || invoice.hasClaimPack) ...<Widget>[
          const SizedBox(height: 12),
          _InvoiceClaimPackCard(
            invoice: invoice,
            onOpenClaimPack: () => _openClaimPack(invoice),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
        SalesDocLinesList(
          currencyCode: vm.meta.currencyCode,
          lines: vm.lines,
          mode: SalesDocMode.view,
          embedInParentScroll: true,
        ),
        SalesDocTotalsStack(
          currencyCode: vm.meta.currencyCode,
          total: vm.meta.total,
          paid: vm.paid > 0 ? vm.paid : null,
          balance: vm.balance,
        ),
        const SizedBox(height: 12),
        PaymentFooter(
          currencyCode: vm.currency,
          invoiceId: invoice.invoiceId,
          canManageInvoices: canManageInvoices,
          pendingAmount: vm.pendingAmount,
          suggestedPhone: suggestedPhone,
          customerName: invoice.customerName,
          invoiceNumber: invoice.invoiceNumber,
          invoiceDate: invoice.date,
          invoiceTotal: invoice.total,
          onPaymentSuccess: () => _refreshInvoiceAndPayments(invoice.invoiceId),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _runAction(Future<void> Function() fn) async {
    if (_acting) return;

    setState(() => _acting = true);

    try {
      await fn();
    } catch (error) {
      SnackService.showError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _acting = false);
      }
    }
  }

  void _openClaimPack(ZohoInvoice invoice) {
    final String claimPackId = (invoice.resolvedClaimPackId ?? '').trim();

    if (claimPackId.isEmpty) {
      SnackService.showError('No claim pack is linked to this invoice.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InsuranceClaimDetailScreen(
          claimPackId: claimPackId,
          patientId: invoice.resolvedPatientId,
        ),
      ),
    );
  }

  _InvoiceVm _buildVm(ZohoInvoice invoice) {
    final String currency = _currency(invoice);

    final SalesDocMetaVm meta = SalesDocMetaVm(
      partyName: _partyName(invoice),
      docNumberOrId: _docNo(invoice),
      status: invoice.status.trim(),
      currencyCode: currency,
      total: invoice.total,
      date: invoice.date,
    );

    final List<SalesDocLineVm> lines = invoice.lineItems
        .map((ZohoInvoiceLineItem lineItem) {
          final String name = lineItem.name.trim();
          final String desc = (lineItem.description ?? '').trim();
          final String title = desc.isNotEmpty ? desc : name;

          return SalesDocLineVm(
            title: title,
            subtitle: desc.isNotEmpty && name.isNotEmpty && name != title
                ? name
                : null,
            qty: lineItem.quantity,
            rate: lineItem.rate,
          );
        })
        .toList(growable: false);

    final num? balance = invoice.balance;
    final num paid = balance == null ? 0 : invoice.total - balance;

    return _InvoiceVm(
      currency: currency,
      meta: meta,
      lines: lines,
      balance: balance,
      paid: paid,
      pendingAmount: balance,
    );
  }

  String? _watchSuggestedPhone(ZohoInvoice invoice) {
    final String contactId = (invoice.customerId ?? '').trim();

    if (contactId.isEmpty) {
      return null;
    }

    final AsyncValue<Object?> contactAsync = ref.watch(
      zohoContactProvider(contactId),
    );

    return contactAsync.maybeWhen(
      data: _bestPhoneFromContactObject,
      orElse: () => null,
    );
  }

  void _maybeSeedPaymentContext({
    required String invoiceId,
    required num? pendingAmount,
    required String? suggestedPhone,
  }) {
    final num? pending = _validPending(pendingAmount);
    final String? phone = _clean(suggestedPhone);

    final bool pendingChanged = pending != _lastSeededPending;
    final bool phoneChanged = phone != _lastSeededPhone;

    if (!pendingChanged && !phoneChanged) return;

    _lastSeededPending = pending;
    _lastSeededPhone = phone;

    if (_seedScheduled) return;
    _seedScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedScheduled = false;

      if (!mounted) return;

      ref
          .read(paymentControllerProvider(invoiceId).notifier)
          .seedFromInvoiceContext(
            pendingAmount: pending,
            suggestedPhone: phone,
          );
    });
  }

  Future<void> _refreshInvoiceAndPayments(String invoiceId) async {
    await ref.read(invoiceControllerProvider.notifier).load(invoiceId);
    await ref.read(paymentControllerProvider(invoiceId).notifier).refresh();
  }

  static num? _validPending(num? value) {
    if (value == null) return null;
    if (!value.isFinite) return null;
    if (value <= 0) return null;

    return value;
  }

  static String? _clean(String? value) {
    final String text = (value ?? '').trim();

    return text.isEmpty ? null : text;
  }

  static String _currency(ZohoInvoice invoice) {
    final String raw = (invoice.currencyCode ?? 'KES').trim();

    return raw.isEmpty ? 'KES' : raw;
  }

  static String _partyName(ZohoInvoice invoice) {
    final String name = invoice.customerName.trim();

    return name.isEmpty ? 'Customer' : name;
  }

  static String _docNo(ZohoInvoice invoice) {
    final String number = (invoice.invoiceNumber ?? '').trim();

    if (number.isNotEmpty) return number;

    final String id = invoice.invoiceId.trim();

    return id.isEmpty ? '-' : id;
  }

  static String? _bestPhoneFromContactObject(Object? contact) {
    if (contact == null) return null;

    String? raw;

    if (contact is ZohoContact) {
      raw = contact.bestPhone.trim();
    } else if (contact is Map<String, Object?>) {
      try {
        raw = ZohoContact.fromJson(contact).bestPhone.trim();
      } catch (_) {}
    } else if (contact is Map) {
      try {
        raw = ZohoContact.fromJson(
          contact.cast<String, Object?>(),
        ).bestPhone.trim();
      } catch (_) {}
    }

    raw ??= _tryReadPhoneDynamically(contact);

    return normalizeMpesaPhoneKE(raw);
  }

  static String? _tryReadPhoneDynamically(Object contact) {
    String? read(Object? value) {
      final String text = (value ?? '').toString().trim();

      return text.isEmpty ? null : text;
    }

    Object? safe(Object? Function() read) {
      try {
        return read();
      } catch (_) {
        return null;
      }
    }

    final dynamic dynamicContact = contact;

    final List<Object?> candidates = <Object?>[
      safe(() => dynamicContact.bestPhone),
      safe(() => dynamicContact.mobile),
      safe(() => dynamicContact.phone),
      safe(() => dynamicContact.personContact?.mobile),
      safe(() => dynamicContact.personContact?.phone),
    ];

    for (final Object? candidate in candidates) {
      final String? phone = read(candidate);

      if (phone != null) {
        return phone;
      }
    }

    return null;
  }
}

class _InvoiceClaimPackCard extends StatelessWidget {
  const _InvoiceClaimPackCard({
    required this.invoice,
    required this.onOpenClaimPack,
  });

  final ZohoInvoice invoice;
  final VoidCallback onOpenClaimPack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? claimPackId = invoice.resolvedClaimPackId;

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.health_and_safety_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Insurance claim',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (claimPackId != null)
                  FilledButton.icon(
                    onPressed: onOpenClaimPack,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open claim pack'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoChip(
                  icon: Icons.payments_outlined,
                  label: invoice.isInsurancePayment
                      ? 'Insurance'
                      : 'Direct pay',
                ),
                if (claimPackId != null)
                  const _InfoChip(
                    icon: Icons.assignment_outlined,
                    label: 'Claim pack linked',
                  )
                else
                  const _InfoChip(
                    icon: Icons.assignment_late_outlined,
                    label: 'No claim pack link',
                  ),
                if (invoice.resolvedPatientNo != null)
                  _InfoChip(
                    icon: Icons.person_outline,
                    label: 'Patient ${invoice.resolvedPatientNo}',
                  ),
                if (invoice.resolvedMembershipId != null)
                  const _InfoChip(
                    icon: Icons.verified_user_outlined,
                    label: 'Membership linked',
                  ),
                if (invoice.resolvedPrescriptionId != null)
                  const _InfoChip(
                    icon: Icons.description_outlined,
                    label: 'Prescription linked',
                  ),
              ],
            ),
            if (claimPackId != null) ...<Widget>[
              const SizedBox(height: 10),
              SelectableText(
                claimPackId,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

@immutable
class _InvoiceVm {
  const _InvoiceVm({
    required this.currency,
    required this.meta,
    required this.lines,
    required this.balance,
    required this.paid,
    required this.pendingAmount,
  });

  final String currency;
  final SalesDocMetaVm meta;
  final List<SalesDocLineVm> lines;
  final num? balance;
  final num paid;
  final num? pendingAmount;
}

class _HeaderStatusPill extends StatelessWidget {
  const _HeaderStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final String text = status.trim();

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SalesDocLeadingIcon(status: text, radius: 14),
        const SizedBox(width: 8),
        SalesDocStatusChip(status: text),
      ],
    );
  }
}
