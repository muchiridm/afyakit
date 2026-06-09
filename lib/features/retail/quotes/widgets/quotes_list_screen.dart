// lib/features/retail/quotes/widgets/quotes_list_screen.dart

import 'dart:async';

import 'package:afyakit/features/retail/quotes/widgets/quote_detail_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_editor_screen.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';

import 'package:afyakit/features/retail/quotes/controllers/quotes_list_controller.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';

import 'package:afyakit/core/home/widgets/home_shell.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/state/paged_query_controller.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';

import 'package:afyakit/features/retail/shared/sales_doc/list_card.dart';
import 'package:afyakit/features/retail/shared/sales_doc/status.dart';

class QuotesListScreen extends ConsumerStatefulWidget {
  const QuotesListScreen({super.key, this.scope = RetailDocScope.all});

  final RetailDocScope scope;

  @override
  ConsumerState<QuotesListScreen> createState() => _QuotesListScreenState();
}

class _QuotesListScreenState extends ConsumerState<QuotesListScreen> {
  static const double _loadMoreThresholdPx = 240;

  /// Keep consistent with invoices list.
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

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      ref
          .read(quotesListControllerProvider(widget.scope).notifier)
          .applySearch(value);
    });
  }

  void _submitSearch(String value) {
    _searchDebounce?.cancel();

    ref
        .read(quotesListControllerProvider(widget.scope).notifier)
        .applySearch(value);
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtl.clear();

    ref.read(quotesListControllerProvider(widget.scope).notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final prov = quotesListControllerProvider(widget.scope);

    final PagedQueryState<ZohoQuote> state = ref.watch(prov);
    final QuotesListController ctl = ref.read(prov.notifier);

    final String title = _isMine ? 'My Quotes' : 'Quotes';

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
          onPressed: state.loading ? null : () => ctl.refresh(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
      fab: FloatingActionButton.extended(
        onPressed: () => _openCatalogToStartNewQuote(context),
        icon: const Icon(Icons.add),
        label: const Text('New quote'),
      ),
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              if (_showSearch) ...<Widget>[
                _QuotesSearchBar(
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
                    onRetry: () => ctl.refresh(reset: true),
                  ),
                ),
              ],
              Expanded(child: _buildBody(context, ref, state, ctl)),
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

  // ─────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────

  void _openCatalogToStartNewQuote(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CatalogScreen()));
  }

  void _openExistingQuote(BuildContext context, ZohoQuote q) {
    final String id = q.quoteId.trim();

    if (id.isEmpty) {
      _toast(context, 'Missing quote id');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => QuoteDetailScreen(quoteId: id)),
    );
  }

  Future<void> _editQuote(
    BuildContext context,
    WidgetRef ref,
    ZohoQuote q,
  ) async {
    // Defensive: member scope should never edit.
    if (_isMine) {
      _toast(context, 'Editing is not available here.');
      return;
    }

    final String id = q.quoteId.trim();

    if (id.isEmpty) {
      _toast(context, 'Missing quote id');
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuoteEditorScreen(editingQuoteId: id),
      ),
    );

    ref
        .read(quotesListControllerProvider(widget.scope).notifier)
        .refresh(reset: true);
  }

  // ─────────────────────────────────────────────
  // Body
  // ─────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    PagedQueryState<ZohoQuote> state,
    QuotesListController ctl,
  ) {
    final bool hasSearch = _searchCtl.text.trim().isNotEmpty;

    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: hasSearch ? 'No matching quotes' : 'No quotes yet',
        subtitle: _isMine
            ? 'Your quotes will appear here once they are created.'
            : hasSearch
            ? 'Try searching by customer, quote number, patient, member number or prescription.'
            : 'Tap “New quote” to build one from the catalog.',
        actionLabel: hasSearch
            ? 'Clear search'
            : (_isMine ? 'Refresh' : 'New quote'),
        onAction: hasSearch
            ? _clearSearch
            : _isMine
            ? () => ctl.refresh(reset: true)
            : () => _openCatalogToStartNewQuote(context),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ctl.refresh(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification n) {
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
          padding: const EdgeInsets.only(top: 0, bottom: 96),
          children: <Widget>[
            SalesListCard(
              title: hasSearch
                  ? 'Search results'
                  : _isMine
                  ? 'Your recent quotes'
                  : 'Recent quotes',
              icon: Icons.receipt_long_outlined,
              children: <Widget>[
                for (final ZohoQuote q in state.items)
                  _QuoteRow(
                    q: q,
                    canEdit: !_isMine,
                    onOpen: () => _openExistingQuote(context, q),
                    onEdit: () => _editQuote(context, ref, q),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ─────────────────────────────────────────────
// Search
// ─────────────────────────────────────────────

class _QuotesSearchBar extends StatelessWidget {
  const _QuotesSearchBar({
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
              hintText: 'Search quotes, customers, patients, members, Rx…',
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

// ─────────────────────────────────────────────
// Row UI (sits inside AppTile via SalesListCard)
// ─────────────────────────────────────────────

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({
    required this.q,
    required this.onOpen,
    required this.onEdit,
    required this.canEdit,
  });

  final ZohoQuote q;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;

    final String customer = q.customerName.trim().isEmpty
        ? 'Customer'
        : q.customerName.trim();

    final String dateText = _formatDate(q.date);
    final String acct = (q.accountNumber ?? '').trim();

    final String currency = (q.currencyCode ?? '').trim();
    final String amount = _formatMoney(q.total, currencyCode: currency);

    final String patientName = (q.patientSnapshot?.fullName ?? '').trim();
    final String patientNo = (q.patientSnapshot?.patientNo ?? '').trim();
    final String memberNo = (q.patientSnapshot?.memberNo ?? '').trim();
    final String scheme = (q.patientSnapshot?.scheme ?? '').trim();
    final String membershipId = (q.resolvedMembershipId ?? '').trim();

    final bool hasInsurance = membershipId.isNotEmpty || memberNo.isNotEmpty;
    final bool hasPatient = patientName.isNotEmpty || patientNo.isNotEmpty;

    return InkWell(
      onTap: onOpen,
      borderRadius: AppShape.tileRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SalesDocLeadingIcon(status: q.status),
            const SizedBox(width: AppShape.gap12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          customer,
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppShape.gap10),
                      SalesDocStatusChip(status: q.status),
                      if (canEdit) ...<Widget>[
                        const SizedBox(width: AppShape.gap6),
                        IconButton(
                          tooltip: 'Edit quote',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppShape.gap6),
                  Wrap(
                    spacing: AppShape.gap10,
                    runSpacing: AppShape.gap6,
                    children: <Widget>[
                      _MetaPill(
                        icon: Icons.calendar_today_outlined,
                        text: dateText,
                      ),
                      if (acct.isNotEmpty)
                        _MetaPill(icon: Icons.badge_outlined, text: acct),
                      if (hasPatient)
                        _MetaPill(
                          icon: Icons.person_outline,
                          text: patientName.isNotEmpty
                              ? patientName
                              : patientNo,
                        ),
                      if (hasInsurance)
                        _MetaPill(
                          icon: Icons.health_and_safety_outlined,
                          text: _insuranceText(
                            memberNo: memberNo,
                            scheme: scheme,
                            membershipId: membershipId,
                          ),
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

  static String _insuranceText({
    required String memberNo,
    required String scheme,
    required String membershipId,
  }) {
    final List<String> parts = <String>[
      if (memberNo.isNotEmpty) 'Member $memberNo',
      if (scheme.isNotEmpty) scheme,
    ];

    if (parts.isNotEmpty) return parts.join(' · ');
    return membershipId.isNotEmpty ? 'Insurance quote' : 'Insurance';
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '—';

    final String y = d.year.toString().padLeft(4, '0');
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');

    return '$y-$m-$day';
  }

  static String _formatMoney(num v, {required String currencyCode}) {
    final NumberFormat nf = NumberFormat.decimalPattern();
    final String code = currencyCode.isEmpty ? 'Total' : currencyCode;

    return '$code ${nf.format(v)}';
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16),
        const SizedBox(width: AppShape.gap6),
        Text(
          text,
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
    final TextTheme t = Theme.of(context).textTheme;

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
              Text(title, style: t.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppShape.gap6),
              Text(subtitle, style: t.bodyMedium, textAlign: TextAlign.center),
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
