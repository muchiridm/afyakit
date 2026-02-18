// lib/features/retail/catalog/widgets/catalog_screen.dart

import 'package:afyakit/features/retail/catalog/controllers/catalog_controller.dart';
import 'package:afyakit/features/retail/catalog/catalog_models.dart';
import 'package:afyakit/features/retail/catalog/catalog_providers.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/shared/layout/app_page.dart';

import 'catalog_components/catalog_header.dart';
import 'catalog_components/catalog_grid.dart';
import 'catalog_components/catalog_ui_bits.dart';

const _priceGreen = Color(0xFF2E7D32);

String _formatPriceCeil(num? v) {
  if (v == null) return '';
  final rounded = v.ceil();
  final nf = NumberFormat.decimalPattern();
  return nf.format(rounded);
}

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    super.key,
    this.initialQuery,
    this.autofocusSearch = false,
  });

  /// Optional initial query (e.g. from guest home search)
  final String? initialQuery;

  /// If true, focus the search field on open.
  final bool autofocusSearch;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _scroll = ScrollController();
  final _searchC = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);

    // Seed search box immediately (UI), then refresh provider query after first frame.
    final seed = (widget.initialQuery ?? '').trim();
    if (seed.isNotEmpty) {
      _searchC.text = seed;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Apply initial query to provider/controller (data)
      final q = (widget.initialQuery ?? '').trim();
      if (q.isNotEmpty) {
        final state = ref.read(catalogControllerProvider);
        final ctrl = ref.read(catalogControllerProvider.notifier);

        // Only refresh if different (avoid redundant reload)
        if (state.query.q.trim() != q) {
          ctrl.refresh(query: state.query.copyWith(q: q));
        }
      }

      // Focus search if requested
      if (widget.autofocusSearch) {
        _searchFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchC.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    final state = ref.read(catalogControllerProvider);
    final atEnd =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 240;

    if (state.hasMore && atEnd) {
      ref.read(catalogControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(catalogItemsProvider);
    final state = ref.watch(catalogControllerProvider);
    final ctrl = ref.read(catalogControllerProvider.notifier);

    // ✅ quote lines state (replaces cart)
    final quoteLinesState = ref.watch(quoteLinesControllerProvider);
    final quoteLineCount = quoteLinesState.lines.length;

    final String? quoteTotalLabel = quoteLineCount == 0
        ? null
        : 'KES ${_formatPriceCeil(quoteLinesState.estimatedTotal)}';

    return AppPage(
      scrollable: true,
      maxWidth: 1100,
      header: CatalogHeader(
        selectedForm: state.query.form,
        onFormChanged: (form) =>
            ctrl.refreshDebounced(query: state.query.copyWith(form: form)),
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
  }

  Widget _buildBody(
    AsyncValue<List<CatalogTile>> itemsAsync,
    CatalogState state,
  ) {
    final ctrl = ref.read(catalogControllerProvider.notifier);

    final int? resultCount = itemsAsync.maybeWhen(
      data: (items) => items.length,
      orElse: () => null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        SearchBarField(
          controller: _searchC,
          focusNode: _searchFocus, // ✅ new (see tiny change below)
          resultCount: resultCount,
          onSubmit: (q) => ctrl.refresh(query: state.query.copyWith(q: q)),
          onChanged: (q) =>
              ctrl.refreshDebounced(query: state.query.copyWith(q: q)),
        ),
        const SizedBox(height: 8),
        itemsAsync.when(
          loading: () => SkeletonGrid(scrollController: _scroll),
          error: (e, _) =>
              ErrorPane(error: '$e', onRetry: () => ctrl.refresh()),
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
    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SheetHeader(
                  tile: t,
                  priceFormatter: _formatPriceCeil,
                  priceColor: _priceGreen,
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Details'),
                        onPressed: () {
                          // TODO: implement details sheet / screen
                        },
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

                          Navigator.of(ctx, rootNavigator: false).maybePop();
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
    );
  }
}
