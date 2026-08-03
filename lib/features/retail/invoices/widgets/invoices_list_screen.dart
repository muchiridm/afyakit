// lib/features/retail/invoices/widgets/invoices_list_screen.dart

import 'dart:async';

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/home/widgets/shared/home_shell.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/retail/invoices/controllers/invoices_list_controller.dart';
import 'package:afyakit/features/retail/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/widgets/invoice_detail_screen.dart';
import 'package:afyakit/features/retail/payments/controllers/payment_controller.dart';
import 'package:afyakit/features/retail/payments/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_detail_screen.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_history_section.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:afyakit/features/retail/shared/sales_doc/list_card.dart';
import 'package:afyakit/features/retail/shared/sales_doc/status.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/state/paged_query_controller.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class InvoicesListScreen extends ConsumerStatefulWidget {
  const InvoicesListScreen({super.key, this.scope = RetailDocScope.all});

  final RetailDocScope scope;

  @override
  ConsumerState<InvoicesListScreen> createState() {
    return _InvoicesListScreenState();
  }
}

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen> {
  static const double _loadMoreThresholdPx = 240;
  static const double _contentMaxW = 720;

  final TextEditingController _searchCtl = TextEditingController();

  Timer? _searchDebounce;

  bool get _isMine => widget.scope == RetailDocScope.mine;

  bool get _showSearch => !_isMine;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = invoicesListControllerProvider(widget.scope);

    final PagedQueryState<ZohoInvoice> state = ref.watch(provider);
    final InvoicesListController controller = ref.read(provider.notifier);

    final me = ref.watch(currentUserProvider).valueOrNull;

    // This screen’s scope is more reliable than workspaceModeProvider.
    // RetailDocScope.mine = member-facing.
    // Any other scope = staff/admin-facing.
    final bool openAsStaff = !_isMine;

    final bool canManagePayments =
        openAsStaff && (me?.canManageInvoices ?? true);

    final String title = _isMine
        ? 'My Invoices and Payments'
        : 'Invoices and Payments';

    return AppPage(
      scrollable: false,
      maxWidth: _contentMaxW,
      title: title,
      showBack: true,
      onBack: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeShell()),
          (_) => false,
        );
      },
      actions: <Widget>[
        IconButton(
          tooltip: 'Refresh',
          onPressed: state.loading
              ? null
              : () => controller.refresh(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
      fab: _isMine
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openCatalogToStartNewInvoice(context),
              icon: const Icon(Icons.add),
              label: const Text('New invoice'),
            ),
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              if (_showSearch) ...<Widget>[
                _InvoicesSearchBar(
                  controller: _searchCtl,
                  loading: state.loading,
                  onChanged: _onSearchChanged,
                  onSubmitted: _submitSearch,
                  onClear: _clearSearch,
                ),
                const SizedBox(height: AppShape.gap12),
              ],
              if (state.error != null) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppShape.gap12),
                  child: _ErrorBanner(
                    message: state.error!,
                    onRetry: () => controller.refresh(reset: true),
                  ),
                ),
              ],
              Expanded(
                child: _buildBody(
                  context: context,
                  state: state,
                  controller: controller,
                  canManagePayments: canManagePayments,
                ),
              ),
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

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      ref
          .read(invoicesListControllerProvider(widget.scope).notifier)
          .applySearch(value);
    });
  }

  void _submitSearch(String value) {
    _searchDebounce?.cancel();

    ref
        .read(invoicesListControllerProvider(widget.scope).notifier)
        .applySearch(value);
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtl.clear();

    ref
        .read(invoicesListControllerProvider(widget.scope).notifier)
        .clearSearch();
  }

  Widget _buildBody({
    required BuildContext context,
    required PagedQueryState<ZohoInvoice> state,
    required InvoicesListController controller,
    required bool canManagePayments,
  }) {
    final bool hasSearch = _searchCtl.text.trim().isNotEmpty;

    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return _EmptyState(
        icon: Icons.receipt_outlined,
        title: hasSearch ? 'No matching invoices' : 'No invoices yet',
        subtitle: _isMine
            ? 'Your invoices and payments will appear here once invoices are issued.'
            : hasSearch
            ? 'Try searching by customer, invoice number, patient, member, claim or prescription.'
            : 'Tap “New invoice” to build one from the catalog.',
        actionLabel: hasSearch
            ? 'Clear search'
            : (_isMine ? 'Refresh' : 'New invoice'),
        onAction: hasSearch
            ? _clearSearch
            : _isMine
            ? () => controller.refresh(reset: true)
            : () => _openCatalogToStartNewInvoice(context),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.refresh(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.metrics.maxScrollExtent <= 0) return false;
          if (!state.hasMore) return false;
          if (state.loadingMore || state.loading) return false;

          final double triggerPoint =
              notification.metrics.maxScrollExtent - _loadMoreThresholdPx;

          if (notification.metrics.pixels >= triggerPoint) {
            controller.loadMore();
          }

          return false;
        },
        child: ListView(
          padding: const EdgeInsets.only(top: 0, bottom: 96),
          children: <Widget>[
            SalesListCard(
              title: hasSearch
                  ? 'Search results'
                  : _isMine
                  ? 'Your recent invoices and payments'
                  : 'Recent invoices and payments',
              icon: Icons.receipt_outlined,
              children: <Widget>[
                for (final ZohoInvoice invoice in state.items)
                  _InvoicePaymentRow(
                    invoice: invoice,
                    canManagePayments: canManagePayments,
                    onOpenInvoice: () => _openExistingInvoice(context, invoice),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openCatalogToStartNewInvoice(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CatalogScreen()));
  }

  void _openExistingInvoice(BuildContext context, ZohoInvoice invoice) {
    final String id = invoice.invoiceId.trim();

    if (id.isEmpty) {
      _toast(context, 'Missing invoice id');
      return;
    }

    final bool openAsStaff = !_isMine;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceDetailScreen(
          invoiceId: id,
          forceStaffWorkspace: openAsStaff,
        ),
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InvoicePaymentRow extends ConsumerStatefulWidget {
  const _InvoicePaymentRow({
    required this.invoice,
    required this.canManagePayments,
    required this.onOpenInvoice,
  });

  final ZohoInvoice invoice;
  final bool canManagePayments;
  final VoidCallback onOpenInvoice;

  @override
  ConsumerState<_InvoicePaymentRow> createState() {
    return _InvoicePaymentRowState();
  }
}

class _InvoicePaymentRowState extends ConsumerState<_InvoicePaymentRow> {
  bool _expanded = false;

  ZohoInvoice get invoice => widget.invoice;

  String get _invoiceId => invoice.invoiceId.trim();

  void _toggleExpanded() {
    if (_invoiceId.isEmpty) return;

    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasInvoiceId = _invoiceId.isNotEmpty;

    PaymentState? paymentState;
    PaymentController? paymentController;

    if (_expanded && hasInvoiceId) {
      final provider = paymentControllerProvider(_invoiceId);
      paymentState = ref.watch(provider);
      paymentController = ref.read(provider.notifier);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _InvoiceRowHeader(
            invoice: invoice,
            expanded: _expanded,
            onToggleExpanded: hasInvoiceId ? _toggleExpanded : null,
            onOpenInvoice: widget.onOpenInvoice,
          ),
          if (_expanded && hasInvoiceId) ...<Widget>[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: PaymentHistorySection(
                title: 'Payments',
                leadingIcon: Icons.payments_outlined,
                currencyCode: _currency(invoice.currencyCode),
                payments:
                    paymentState?.payments ?? const <ZohoInvoicePayment>[],
                loading: paymentState?.loadingPayments ?? false,
                busy: paymentState?.busy ?? false,
                error: paymentState?.error,
                canManage: widget.canManagePayments,
                showHeader: true,
                showEmptyCard: true,
                compact: true,
                maxRows: null,
                onRefresh: paymentController == null
                    ? () async {}
                    : paymentController.refresh,
                onRecord: null,
                onOpenReceipt: (ZohoInvoicePayment payment) {
                  _openPaymentDetail(context, payment);
                },
                onEdit: null,
                onDelete: null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openPaymentDetail(BuildContext context, ZohoInvoicePayment payment) {
    final String paymentId = payment.paymentId.trim();

    if (paymentId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Missing payment id')));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentDetailScreen(
          invoiceId: _invoiceId,
          paymentId: paymentId,
          currencyCode: _currency(invoice.currencyCode),
          customerName: invoice.customerName,
          invoiceNumber: invoice.invoiceNumber,
          invoiceDate: invoice.date,
          invoiceTotal: invoice.total,
          canManagePayments: widget.canManagePayments,
        ),
      ),
    );
  }

  static String _currency(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? 'KES' : text;
  }
}

class _InvoiceRowHeader extends StatelessWidget {
  const _InvoiceRowHeader({
    required this.invoice,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onOpenInvoice,
  });

  static const double _wideLayoutMinWidth = 560;

  final ZohoInvoice invoice;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final VoidCallback onOpenInvoice;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= _wideLayoutMinWidth;

        return wide ? _buildWide(context) : _buildCompactPhone(context);
      },
    );
  }

  Widget _buildWide(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String customer = _customerName(invoice);
    final String invoiceLabel = _invoiceLabel(invoice);
    final String dateText = _formatDate(invoice.date);
    final String accountRef = (invoice.accountNumber ?? '').trim();

    final String currency = (invoice.currencyCode ?? '').trim();
    final String amount = _formatMoney(invoice.total, currencyCode: currency);

    final String expandTooltip = expanded ? 'Hide payments' : 'Show payments';

    return Material(
      color: Colors.transparent,
      borderRadius: AppShape.tileRadius,
      child: InkWell(
        onTap: onToggleExpanded,
        borderRadius: AppShape.tileRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SalesDocLeadingIcon(status: invoice.status),
              const SizedBox(width: AppShape.gap12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          flex: 5,
                          child: Text(
                            customer,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppShape.gap10),
                        Flexible(
                          flex: 4,
                          child: _InvoiceLink(
                            label: invoiceLabel,
                            onTap: onOpenInvoice,
                          ),
                        ),
                        const SizedBox(width: AppShape.gap10),
                        SalesDocStatusChip(status: invoice.status),
                      ],
                    ),
                    const SizedBox(height: AppShape.gap6),
                    Wrap(
                      spacing: AppShape.gap10,
                      runSpacing: AppShape.gap4,
                      children: <Widget>[
                        _MetaPill(
                          icon: Icons.calendar_today_outlined,
                          text: dateText,
                        ),
                        if (accountRef.isNotEmpty)
                          _MetaPill(icon: Icons.tag_outlined, text: accountRef),
                        if (invoice.isInsurancePayment)
                          const _MetaPill(
                            icon: Icons.health_and_safety_outlined,
                            text: 'Insurance',
                          ),
                        if (invoice.hasClaimPack)
                          const _MetaPill(
                            icon: Icons.assignment_outlined,
                            text: 'Claim pack linked',
                          ),
                        if (invoice.resolvedPatientNo != null)
                          _MetaPill(
                            icon: Icons.person_outline,
                            text: 'Patient ${invoice.resolvedPatientNo}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppShape.gap12),
              Text(
                amount,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppShape.gap6),
              IconButton(
                tooltip: expandTooltip,
                onPressed: onToggleExpanded,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  expanded
                      ? Icons.expand_less_outlined
                      : Icons.expand_more_outlined,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactPhone(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String customer = _customerName(invoice);
    final String invoiceLabel = _invoiceLabel(invoice);
    final String dateText = _formatDate(invoice.date);
    final String accountRef = (invoice.accountNumber ?? '').trim();

    final String currency = (invoice.currencyCode ?? '').trim();
    final String amount = _formatMoney(invoice.total, currencyCode: currency);

    final String expandTooltip = expanded ? 'Hide payments' : 'Show payments';

    return Material(
      color: Colors.transparent,
      borderRadius: AppShape.tileRadius,
      child: InkWell(
        onTap: onToggleExpanded,
        borderRadius: AppShape.tileRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SalesDocLeadingIcon(status: invoice.status),
              const SizedBox(width: AppShape.gap12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            customer,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppShape.gap10),
                        SalesDocStatusChip(status: invoice.status),
                      ],
                    ),
                    const SizedBox(height: AppShape.gap6),
                    _InvoiceLink(label: invoiceLabel, onTap: onOpenInvoice),
                    const SizedBox(height: AppShape.gap6),
                    Wrap(
                      spacing: AppShape.gap10,
                      runSpacing: AppShape.gap6,
                      children: <Widget>[
                        _MetaPill(
                          icon: Icons.calendar_today_outlined,
                          text: dateText,
                        ),
                        if (accountRef.isNotEmpty)
                          _MetaPill(icon: Icons.tag_outlined, text: accountRef),
                        if (invoice.isInsurancePayment)
                          const _MetaPill(
                            icon: Icons.health_and_safety_outlined,
                            text: 'Insurance',
                          ),
                        if (invoice.hasClaimPack)
                          const _MetaPill(
                            icon: Icons.assignment_outlined,
                            text: 'Claim pack linked',
                          ),
                        if (invoice.resolvedPatientNo != null)
                          _MetaPill(
                            icon: Icons.person_outline,
                            text: 'Patient ${invoice.resolvedPatientNo}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppShape.gap12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    amount,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    tooltip: expandTooltip,
                    onPressed: onToggleExpanded,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      expanded
                          ? Icons.expand_less_outlined
                          : Icons.expand_more_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _customerName(ZohoInvoice invoice) {
    final String customer = invoice.customerName.trim();

    return customer.isEmpty ? 'Customer' : customer;
  }

  static String _invoiceLabel(ZohoInvoice invoice) {
    final String number = (invoice.invoiceNumber ?? '').trim();

    if (number.isNotEmpty) return 'Invoice $number';

    final String id = invoice.invoiceId.trim();

    return id.isEmpty ? 'Open invoice' : 'Invoice $id';
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '—';

    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static String _formatMoney(num value, {required String currencyCode}) {
    final NumberFormat formatter = NumberFormat.decimalPattern();
    final String code = currencyCode.trim().isEmpty ? 'Total' : currencyCode;

    return '$code ${formatter.format(value)}';
  }
}

class _InvoiceLink extends StatelessWidget {
  const _InvoiceLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.open_in_new_outlined, size: 15, color: scheme.primary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoicesSearchBar extends StatelessWidget {
  const _InvoicesSearchBar({
    required this.controller,
    required this.loading,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool loading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppTile(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (BuildContext context, TextEditingValue value, _) {
          final bool hasQuery = value.text.trim().isNotEmpty;

          return TextField(
            controller: controller,
            enabled: !loading,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search invoices, customers, patients, claims, Rx…',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClear,
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16),
        const SizedBox(width: AppShape.gap6),
        Text(
          text,
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).hintColor,
          ),
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return AppTile(
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: AppShape.gap10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
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
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 44),
              const SizedBox(height: AppShape.gap12),
              Text(
                title,
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppShape.gap6),
              Text(
                subtitle,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppShape.gap16),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(
                  actionLabel == 'Refresh' ? Icons.refresh : Icons.add,
                ),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
