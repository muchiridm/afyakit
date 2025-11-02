// lib/core/catalog/widgets/catalog_screen.dart
import 'package:afyakit/api/dawaindex/providers.dart';
import 'package:afyakit/core/catalog/catalog_controller.dart';
import 'package:afyakit/core/catalog/catalog_models.dart';
import 'package:afyakit/core/catalog/catalog_providers.dart';
import 'package:afyakit/core/catalog/widgets/catalog_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/shared/widgets/base_screen.dart';
import 'package:afyakit/core/auth_users/guards/require_auth.dart';

import 'search_bar.dart';
import 'catalog_grid.dart';
import 'skeletons.dart';
import 'error_pane.dart';
import 'sheet_header.dart';

const _priceGreen = Color(0xFF2E7D32);

String _formatPriceCeil(num? v) {
  if (v == null) return '';
  final rounded = v.ceil();
  final nf = NumberFormat.decimalPattern();
  return nf.format(rounded);
}

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _scroll = ScrollController();
  final _searchC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchC.dispose();
    super.dispose();
  }

  void _onScroll() {
    final ctrl = ref.read(catalogControllerProvider.notifier);
    final atEnd =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 240;
    if (ref.read(catalogControllerProvider).hasMore && atEnd) {
      ctrl.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final diClientAsync = ref.watch(diApiClientProvider);

    return diClientAsync.when(
      // ─── LOADING ───
      loading: () => BaseScreen(
        scrollable: true,
        maxContentWidth: 1100,
        header: CatalogHeader(selectedForm: '', onFormChanged: (_) {}),
        body: const Center(child: CircularProgressIndicator()),
      ),

      // ─── ERROR ───
      error: (e, _) => BaseScreen(
        scrollable: true,
        maxContentWidth: 1100,
        header: CatalogHeader(selectedForm: '', onFormChanged: (_) {}),
        body: Center(
          child: Text(
            'Failed to load catalog source:\n$e',
            textAlign: TextAlign.center,
          ),
        ),
      ),

      // ─── DATA ───
      data: (_) {
        final itemsAsync = ref.watch(catalogItemsProvider);
        final state = ref.watch(catalogControllerProvider);
        final ctrl = ref.read(catalogControllerProvider.notifier);

        return BaseScreen(
          scrollable: true,
          maxContentWidth: 1100,
          header: CatalogHeader(
            selectedForm: state.query.form,
            onFormChanged: (form) =>
                ctrl.refreshDebounced(query: state.query.copyWith(form: form)),
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
    final ctrl = ref.read(catalogControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        SearchBarField(
          controller: _searchC,
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
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add to cart'),
                        onPressed: () async {
                          final ok = await requireAuth(ctx, ref);
                          if (!ok) return;
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
