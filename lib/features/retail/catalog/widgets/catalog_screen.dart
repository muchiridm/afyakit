// lib/features/retail/catalog/widgets/catalog_screen.dart

import 'dart:async';

import 'package:afyakit/features/retail/catalog/catalog_controller.dart';
import 'package:afyakit/features/retail/catalog/catalog_providers.dart';
import 'package:afyakit/features/retail/catalog/models/catalog_models.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_components/catalog_disclaimer.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_components/catalog_discovery.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_components/catalog_filter_bar.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_editor_screen.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'catalog_components/catalog_grid.dart';
import 'catalog_components/catalog_header.dart';
import 'catalog_components/catalog_ui_bits.dart';

const _priceGreen = Color(0xFF2E7D32);

String _formatPriceCeil(num? v) {
  if (v == null) return '';
  final int rounded = v.ceil();
  final NumberFormat nf = NumberFormat.decimalPattern();
  return nf.format(rounded);
}

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    super.key,
    this.initialQuery,
    this.autofocusSearch = false,
  });

  final String? initialQuery;
  final bool autofocusSearch;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchC = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _seedApplied = false;

  bool get _showDiscovery {
    final CatalogState state = ref.read(catalogControllerProvider);
    return state.query.q.trim().isEmpty && state.query.form.trim().isEmpty;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);

    final String seed = (widget.initialQuery ?? '').trim();
    if (seed.isNotEmpty) {
      _searchC.text = seed;
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchC.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _applyInitialQueryIfNeeded() {
    if (_seedApplied) return;
    if (!mounted) return;

    _seedApplied = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final String q = (widget.initialQuery ?? '').trim();
      final CatalogController ctrl = ref.read(
        catalogControllerProvider.notifier,
      );
      final CatalogState state = ref.read(catalogControllerProvider);

      if (q.isNotEmpty && state.query.q.trim() != q) {
        // ignore: discarded_futures
        ctrl.refresh(query: state.query.copyWith(q: q));
      }

      if (widget.autofocusSearch) {
        _searchFocus.requestFocus();
      }
    });
  }

  void _onScroll() {
    if (!mounted) return;
    if (_showDiscovery) return;
    if (!_scroll.hasClients) return;

    final CatalogState state = ref.read(catalogControllerProvider);
    final bool atEnd =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 240;

    if (state.hasMore && atEnd) {
      // ignore: discarded_futures
      ref.read(catalogControllerProvider.notifier).loadMore();
    }
  }

  void _applySearch(String q, CatalogState state) {
    if (!mounted) return;

    final String next = q.trim();
    _searchC.text = next;
    _searchC.selection = TextSelection.collapsed(offset: _searchC.text.length);

    // ignore: discarded_futures
    ref
        .read(catalogControllerProvider.notifier)
        .refresh(query: state.query.copyWith(q: next));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> readyAsync = ref.watch(catalogReadyProvider);

    return readyAsync.when(
      loading: () => const AppPage(
        scrollable: true,
        maxWidth: 1100,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppPage(
        scrollable: true,
        maxWidth: 1100,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Failed to initialize catalog: $e'),
          ),
        ),
      ),
      data: (_) {
        _applyInitialQueryIfNeeded();

        final AsyncValue<List<CatalogTile>> itemsAsync = ref.watch(
          catalogItemsProvider,
        );
        final CatalogState state = ref.watch(catalogControllerProvider);
        final CatalogController ctrl = ref.read(
          catalogControllerProvider.notifier,
        );

        final quoteLinesState = ref.watch(quoteLinesControllerProvider);
        final int quoteLineCount = quoteLinesState.lines.length;

        final String? quoteTotalLabel = quoteLineCount == 0
            ? null
            : 'KES ${_formatPriceCeil(quoteLinesState.estimatedTotal)}';

        return AppPage(
          scrollable: true,
          maxWidth: 1100,
          header: CatalogHeader(
            selectedForm: state.query.form,
            onFormChanged: (form) {
              ctrl.refreshDebounced(query: state.query.copyWith(form: form));
            },
            quoteItemCount: quoteLineCount,
            quoteTotalLabel: quoteTotalLabel,
            onClearQuote: quoteLineCount == 0
                ? null
                : () {
                    ref.read(quoteLinesControllerProvider.notifier).clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Quote cleared'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
            onViewQuote: quoteLineCount == 0
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const QuoteEditorScreen(),
                      ),
                    );
                  },
          ),
          body: _buildBody(itemsAsync, state),
        );
      },
    );
  }

  Widget _buildBody(
    AsyncValue<List<CatalogTile>> itemsAsync,
    CatalogState state,
  ) {
    final CatalogController ctrl = ref.read(catalogControllerProvider.notifier);
    final bool showDiscovery =
        state.query.q.trim().isEmpty && state.query.form.trim().isEmpty;

    final int? resultCount = showDiscovery
        ? null
        : itemsAsync.maybeWhen(
            data: (items) => items.length,
            orElse: () => null,
          );

    final bool hasActiveFilters =
        state.query.q.trim().isNotEmpty || state.query.form.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        SearchBarField(
          controller: _searchC,
          focusNode: _searchFocus,
          resultCount: resultCount,
          showClear: hasActiveFilters,
          onClear: () {
            if (!mounted) return;
            _searchC.clear();
            // ignore: discarded_futures
            ctrl.refresh(query: const CatalogQuery());
          },
          onSubmit: (q) {
            if (!mounted) return;
            // ignore: discarded_futures
            ctrl.refresh(query: state.query.copyWith(q: q));
          },
          onChanged: (q) {
            if (!mounted) return;
            ctrl.refreshDebounced(query: state.query.copyWith(q: q));
          },
        ),
        const SizedBox(height: 8),
        const CatalogDisclaimer(),
        const SizedBox(height: 14),
        CatalogFiltersBar(
          selectedForm: state.query.form,
          onSelectForm: (form) {
            // ignore: discarded_futures
            ctrl.refresh(query: state.query.copyWith(form: form));
          },
        ),
        const SizedBox(height: 14),
        if (showDiscovery)
          CatalogDiscovery(onExampleTap: (q) => _applySearch(q, state))
        else
          itemsAsync.when(
            loading: () => SkeletonGrid(scrollController: _scroll),
            error: (e, _) => ErrorPane(
              error: '$e',
              onRetry: () {
                // ignore: discarded_futures
                ctrl.refresh();
              },
            ),
            data: (items) => CatalogGrid(
              items: items,
              scrollController: _scroll,
              onTapTile: (t) => _showTileSheet(context, t),
              showTailLoader: state.hasMore,
              priceFormatter: _formatPriceCeil,
              priceColor: _priceGreen,
            ),
          ),
      ],
    );
  }

  Future<void> _showTileSheet(BuildContext context, CatalogTile t) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          child: Material(
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            color: Theme.of(ctx).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SheetHeader(
                    tile: t,
                    priceFormatter: _formatPriceCeil,
                    priceColor: _priceGreen,
                  ),
                  const Divider(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Details'),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Add to quote'),
                          onPressed: () {
                            ref
                                .read(quoteLinesControllerProvider.notifier)
                                .addOrIncrement(t);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Added to quote'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                            Navigator.of(ctx).maybePop();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
