// lib/features/retail/invoices/widgets/invoice_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';

import 'package:afyakit/features/retail/invoices/controllers/invoice_action_controller.dart';
import 'package:afyakit/features/retail/invoices/controllers/invoice_controller.dart';

import 'package:afyakit/features/retail/payments/controllers/payment_controller.dart';
import 'package:afyakit/features/retail/contacts/zoho_contact.dart';
import 'package:afyakit/features/retail/invoices/zoho_invoice.dart';

import 'package:afyakit/features/retail/shared/sales_doc/feedback.dart';
import 'package:afyakit/features/retail/shared/sales_doc/header.dart';
import 'package:afyakit/features/retail/shared/sales_doc/lines.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:afyakit/features/retail/shared/sales_doc/status.dart';
import 'package:afyakit/features/retail/shared/sales_doc/totals.dart';

import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/utils/normalize/normalize_phone.dart';

import '../../payments/widgets/payment_footer.dart';

// ✅ Already exists in app
import 'package:afyakit/features/retail/payments/providers/payment_receipt_providers.dart';

enum _InvoiceMenuAction { send, markSent }

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  static const double _contentMaxW = 720;

  bool _booted = false;
  bool _acting = false;

  // Prevent noisy repeated seeding on every rebuild
  String? _lastSeededPhone;
  num? _lastSeededPending;

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

  Future<void> _runAction(Future<void> Function() fn) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await fn();
    } catch (e) {
      SnackService.showError(e.toString());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final canManageInvoices = me?.canManageInvoices ?? false;

    final s = ref.watch(invoiceControllerProvider);

    final actionsCtl = ref.read(invoiceActionControllerProvider);

    final pdfBusy = _acting || s.downloadingPdf;
    final menuBusy = _acting || s.busy;

    return AppPage(
      title: 'Invoice',
      showBack: true,
      maxWidth: _contentMaxW,
      scrollable: true,
      actions: _buildActions(
        canManageInvoices: canManageInvoices,
        state: s,
        pdfBusy: pdfBusy,
        menuBusy: menuBusy,
        actionsCtl: actionsCtl,
      ),
      body: _buildBody(context, s, canManageInvoices: canManageInvoices),
      footer: null,
    );
  }

  List<Widget> _buildActions({
    required bool canManageInvoices,
    required InvoiceState state,
    required bool pdfBusy,
    required bool menuBusy,
    required InvoiceActionController actionsCtl,
  }) {
    return [
      IconButton(
        tooltip: pdfBusy ? 'Working…' : 'PDF',
        onPressed: pdfBusy
            ? null
            : () => _runAction(
                () => actionsCtl.viewPdf(context, invoiceId: widget.invoiceId),
              ),
        icon: const Icon(Icons.picture_as_pdf_outlined),
      ),
      IconButton(
        tooltip: 'Refresh',
        onPressed: state.busy
            ? null
            : () => _runAction(() => actionsCtl.refresh(widget.invoiceId)),
        icon: const Icon(Icons.refresh),
      ),
      if (canManageInvoices)
        PopupMenuButton<_InvoiceMenuAction>(
          tooltip: 'More',
          enabled: !menuBusy,
          onSelected: (a) async {
            switch (a) {
              case _InvoiceMenuAction.send:
                await _runAction(
                  () => actionsCtl.sendInvoice(
                    context,
                    invoiceId: widget.invoiceId,
                  ),
                );
                break;
              case _InvoiceMenuAction.markSent:
                await _runAction(
                  () =>
                      actionsCtl.markSent(context, invoiceId: widget.invoiceId),
                );
                break;
            }
          },
          itemBuilder: (context) => const [
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
    InvoiceState s, {
    required bool canManageInvoices,
  }) {
    if (s.loading && !s.hasInvoice) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!s.hasInvoice) {
      return SalesDocErrorState(
        title: 'Failed to load invoice',
        message: (s.error ?? 'No invoice data'),
      );
    }

    final ZohoInvoice inv = s.invoice!;
    final vm = _buildVm(inv);

    final suggestedPhone = _watchSuggestedPhone(inv);
    _maybeSeedPaymentContext(
      invoiceId: inv.invoiceId,
      pendingAmount: vm.pendingAmount,
      suggestedPhone: suggestedPhone,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_acting || s.busy) const LinearProgressIndicator(minHeight: 2),
        InlineErrorCard(message: (s.error ?? '').trim()),

        SalesDocHeader(
          title: 'Invoice',
          meta: vm.meta,
          showStatus: false,
          trailing: _HeaderStatusPill(status: vm.meta.status),
        ),

        const Divider(height: 1),

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
        const Divider(height: 1),
        const SizedBox(height: 12),

        PaymentFooter(
          currencyCode: vm.currency,
          invoiceId: inv.invoiceId,
          canManageInvoices: canManageInvoices,
          pendingAmount: vm.pendingAmount,
          suggestedPhone: suggestedPhone,
          customerName: inv.customerName,
          invoiceNumber: inv.invoiceNumber,
          invoiceDate: inv.date,
          invoiceTotal: inv.total,
          onPaymentSuccess: () => _refreshInvoiceAndPayments(inv.invoiceId),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ───────────────────────── VM / Data helpers ─────────────────────────

  _InvoiceVm _buildVm(ZohoInvoice inv) {
    final currency = _currency(inv);

    final meta = SalesDocMetaVm(
      partyName: _partyName(inv),
      docNumberOrId: _docNo(inv),
      status: inv.status.trim(),
      currencyCode: currency,
      total: inv.total,
      date: inv.date,
    );

    final lines = inv.lineItems
        .map(
          (li) => SalesDocLineVm(
            title: (li.description ?? '').trim().isNotEmpty
                ? (li.description ?? '').trim()
                : li.name.trim(),
            subtitle: _subtitle(li),
            qty: li.quantity,
            rate: li.rate,
          ),
        )
        .toList(growable: false);

    final num? balance = inv.balance;
    final num paid = (balance == null) ? 0 : (inv.total - balance);

    return _InvoiceVm(
      currency: currency,
      meta: meta,
      lines: lines,
      balance: balance,
      paid: paid,
      pendingAmount: balance,
    );
  }

  String? _watchSuggestedPhone(ZohoInvoice inv) {
    final contactId = (inv.customerId ?? '').trim();
    final contactAsync = contactId.isEmpty
        ? const AsyncValue<Object?>.data(null)
        : ref.watch(zohoContactProvider(contactId));

    return contactAsync.maybeWhen(
      data: (c) => _bestPhoneFromContactObject(c),
      orElse: () => null,
    );
  }

  bool _seedScheduled = false;

  void _maybeSeedPaymentContext({
    required String invoiceId,
    required num? pendingAmount,
    required String? suggestedPhone,
  }) {
    final pending = _normPending(pendingAmount);
    final phone = _normPhone(suggestedPhone);

    final didPendingChange = pending != _lastSeededPending;
    final didPhoneChange = phone != _lastSeededPhone;

    if (!didPendingChange && !didPhoneChange) return;

    _lastSeededPending = pending;
    _lastSeededPhone = phone;

    // ✅ Never write providers during build.
    // Schedule a single post-frame write. If build runs again before frame ends,
    // we still only seed once.
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

  static num? _normPending(num? v) {
    if (v == null) return null;
    if (!v.isFinite) return null;
    if (v <= 0) return null;
    return v;
  }

  static String? _normPhone(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty ? null : s;
  }

  static String _currency(ZohoInvoice inv) {
    final raw = (inv.currencyCode ?? 'KES').trim();
    return raw.isEmpty ? 'KES' : raw;
  }

  static String _partyName(ZohoInvoice inv) {
    final n = inv.customerName.trim();
    return n.isEmpty ? 'Customer' : n;
  }

  static String _docNo(ZohoInvoice inv) {
    final n = (inv.invoiceNumber ?? '').trim();
    if (n.isNotEmpty) return n;
    final id = inv.invoiceId.trim();
    return id.isEmpty ? '-' : id;
  }

  static String? _subtitle(ZohoInvoiceLineItem li) {
    final name = li.name.trim();
    final desc = (li.description ?? '').trim();
    final title = desc.isNotEmpty ? desc : name;
    if (desc.isNotEmpty && name.isNotEmpty && name != title) return name;
    return null;
  }

  static String? _bestPhoneFromContactObject(Object? contact) {
    String? raw;

    if (contact == null) return null;

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

    raw ??= (() {
      String? norm(Object? v) {
        final s = (v ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }

      Object? safe(Object? Function() fn) {
        try {
          return fn();
        } catch (_) {
          return null;
        }
      }

      final d = contact as dynamic;
      final cands = <Object?>[
        safe(() => d.bestPhone),
        safe(() => d.mobile),
        safe(() => d.phone),
        safe(() => d.personContact?.mobile),
        safe(() => d.personContact?.phone),
      ];

      for (final v in cands) {
        final s = norm(v);
        if (s != null) return s;
      }
      return null;
    })();

    return normalizeMpesaPhoneKE(raw);
  }

  Future<void> _refreshInvoiceAndPayments(String invoiceId) async {
    await ref.read(invoiceControllerProvider.notifier).load(invoiceId);
    await ref.read(paymentControllerProvider(invoiceId).notifier).refresh();
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
