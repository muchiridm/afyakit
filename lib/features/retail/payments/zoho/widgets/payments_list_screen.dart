// lib/features/retail/payments/zoho/widgets/payments_list_screen.dart

import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:afyakit/features/retail/payments/zoho/providers/payment_invoice_summary_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/core/home/widgets/home_shell.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/state/paged_query_controller.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';

import 'package:afyakit/features/retail/shared/sales_doc/list_card.dart';

import 'package:afyakit/features/retail/payments/zoho/controllers/payments_list_controller.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';

class PaymentsListScreen extends ConsumerWidget {
  const PaymentsListScreen({super.key, this.scope = RetailDocScope.all});

  final RetailDocScope scope;

  static const double _loadMoreThresholdPx = 240;
  static const double _contentMaxW = 720;

  bool get _isMine => scope == RetailDocScope.mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentsListControllerProvider(scope));
    final ctl = ref.read(paymentsListControllerProvider(scope).notifier);

    final title = _isMine ? 'My Payments' : 'Payments';

    return AppPage(
      scrollable: false,
      maxWidth: _contentMaxW,
      title: title,
      showBack: true,
      onBack: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (_) => false,
        );
      },
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: state.loading ? null : () => ctl.refresh(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
      fab: null,
      body: Stack(
        children: [
          Column(
            children: [
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppShape.gap12),
                  child: _ErrorBanner(
                    message: state.error!,
                    onRetry: () => ctl.refresh(reset: true),
                  ),
                ),
              Expanded(child: _buildBody(context, state, ctl)),
              if (state.loadingMore)
                const Padding(
                  padding: EdgeInsets.only(top: AppShape.gap8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
          if (state.loading && state.items.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PagedQueryState<ZohoInvoicePayment> state,
    PaymentsListController ctl,
  ) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return _EmptyState(
        icon: Icons.payments_outlined,
        title: 'No payments yet',
        subtitle: _isMine
            ? 'Your payments will appear here after they are recorded.'
            : 'Payments will appear here after they are recorded.',
        actionLabel: 'Refresh',
        onAction: () => ctl.refresh(reset: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ctl.refresh(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.maxScrollExtent <= 0) return false;
          if (!state.hasMore) return false;
          if (state.loadingMore || state.loading) return false;

          if (n.metrics.pixels >=
              n.metrics.maxScrollExtent - _loadMoreThresholdPx) {
            ctl.loadMore();
          }
          return false;
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            SalesListCard(
              title: _isMine ? 'Your recent payments' : 'Recent payments',
              icon: Icons.payments_outlined,
              children: [
                for (final p in state.items)
                  _PaymentRow(
                    payment: p,
                    onOpen: () => ctl.openPayment(context, p),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends ConsumerWidget {
  const _PaymentRow({required this.payment, required this.onOpen});

  final ZohoInvoicePayment payment;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;

    final paymentId = payment.paymentId.trim();
    final pidLabel = paymentId.isEmpty ? 'Payment' : paymentId;

    final dateText = _formatDate(payment.date);
    final mode = (payment.mode ?? '').trim();
    final desc = (payment.description ?? '').trim();
    final amount = _formatAmount(payment.amount);

    final invoiceId = (payment.invoiceId ?? '').trim();

    final invAsync = invoiceId.isEmpty
        ? null
        : ref.watch(paymentInvoiceSummaryProvider(invoiceId));

    final customerName =
        invAsync?.when(
          data: (inv) => inv.customerName.trim(),
          loading: () => '',
          error: (_, __) => '',
        ) ??
        '';

    final invoiceNo =
        invAsync?.when(
          data: (inv) => (inv.invoiceNumber ?? '').trim(),
          loading: () => '',
          error: (_, __) => '',
        ) ??
        '';

    final title = customerName.isNotEmpty ? customerName : pidLabel;

    return InkWell(
      onTap: onOpen,
      borderRadius: AppShape.tileRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LeadingIcon(),
            const SizedBox(width: AppShape.gap12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppShape.gap6),
                  Wrap(
                    spacing: AppShape.gap10,
                    runSpacing: AppShape.gap6,
                    children: [
                      _MetaPill(
                        icon: Icons.calendar_today_outlined,
                        text: dateText,
                      ),
                      if (invoiceNo.isNotEmpty)
                        _MetaPill(
                          icon: Icons.receipt_long_outlined,
                          text: invoiceNo,
                        ),
                      _MetaPill(icon: Icons.tag_outlined, text: pidLabel),
                      if (mode.isNotEmpty)
                        _MetaPill(icon: Icons.payments_outlined, text: mode),
                      if (desc.isNotEmpty)
                        _MetaPill(icon: Icons.notes_outlined, text: desc),
                      if (invoiceNo.isEmpty && invoiceId.isNotEmpty)
                        _MetaPill(icon: Icons.tag_outlined, text: invoiceId),
                      if (invoiceId.isNotEmpty && invAsync?.isLoading == true)
                        const _MetaPill(
                          icon: Icons.hourglass_top,
                          text: 'Loading…',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppShape.gap12),
            Text(
              amount,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('yyyy-MM-dd').format(d);
  }

  static String _formatAmount(num v) {
    final nf = NumberFormat.decimalPattern();
    return nf.format(v);
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: const Icon(Icons.payments_outlined, size: 18),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: AppShape.gap6),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppTile(
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: AppShape.gap10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Retry',
            onPressed: onRetry,
            icon: Icon(Icons.refresh, color: scheme.error),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44),
              const SizedBox(height: AppShape.gap12),
              Text(title, style: t.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppShape.gap6),
              Text(subtitle, style: t.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppShape.gap16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
