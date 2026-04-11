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
import 'package:afyakit/shared/utils/app_error_message.dart';
import 'package:afyakit/shared/widgets/app_error_pane.dart';
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
      ref.read(catalogControllerProvider.notifier).loadMore();
    }
  }

  void _applySearch(String q, CatalogState state) {
    if (!mounted) return;

    final String next = q.trim();
    _searchC.text = next;
    _searchC.selection = TextSelection.collapsed(offset: _searchC.text.length);

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
          child: AppErrorPane(
            title: 'Catalog temporarily unavailable',
            message: appErrorMessage(
              e,
              fallback:
                  'We could not initialize the catalog right now. Please try again shortly.',
            ),
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
            ctrl.refresh(query: const CatalogQuery());
          },
          onSubmit: (q) {
            if (!mounted) return;
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
            ctrl.refresh(query: state.query.copyWith(form: form));
          },
        ),
        const SizedBox(height: 14),
        if (showDiscovery)
          CatalogDiscovery(onExampleTap: (q) => _applySearch(q, state))
        else
          itemsAsync.when(
            loading: () => SkeletonGrid(scrollController: _scroll),
            error: (e, _) => AppErrorPane(
              title: 'Catalog temporarily unavailable',
              message: appErrorMessage(
                e,
                fallback:
                    'We could not load the catalog right now. Please try again shortly.',
              ),
              onRetry: () {
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
    final String whoPreview = t.whoPathPreview?.trim() ?? '';
    final String whoAtcCode = t.whoAtcCode?.trim() ?? '';
    final List<String> atcLabels = t.whoAtcLabels ?? const <String>[];
    final bool hasCombo = atcLabels.length > 1;

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
                  if (whoPreview.isNotEmpty ||
                      whoAtcCode.isNotEmpty ||
                      atcLabels.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (whoAtcCode.isNotEmpty)
                            Text(
                              'ATC: $whoAtcCode',
                              style: Theme.of(ctx).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      ctx,
                                    ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          if (whoPreview.isNotEmpty)
                            Text(
                              whoPreview,
                              style: Theme.of(ctx).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      ctx,
                                    ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          if (hasCombo) ...[
                            const SizedBox(height: 4),
                            Text(
                              atcLabels.join(', '),
                              style: Theme.of(ctx).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      ctx,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Details'),
                          onPressed: () {
                            Navigator.of(ctx).maybePop();
                            _showTileDetails(context, t);
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

  Future<void> _showTileDetails(BuildContext context, CatalogTile t) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          child: Material(
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            color: Theme.of(ctx).colorScheme.surface,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.tileTitle?.trim().isNotEmpty == true
                        ? t.tileTitle!.trim()
                        : t.titleLine,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if ((t.tileDescWithWhoPath ?? '').trim().isNotEmpty)
                    Text(
                      t.tileDescWithWhoPath!.trim(),
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 16),
                  _detailRow(ctx, 'Brand', t.brand),
                  _detailRow(ctx, 'Strength', t.strengthSig),
                  _detailRow(ctx, 'Form', t.form),
                  _detailRow(ctx, 'Pack count', t.bestPackCount?.toString()),
                  _detailRow(ctx, 'Manufacturer', t.supplierManufacturer),
                  _detailRow(ctx, 'Volume', t.volumeSig),
                  _detailRow(ctx, 'Concentration', t.concentrationSig),
                  _detailRow(ctx, 'Offers', t.offerCount?.toString()),
                  _detailRow(
                    ctx,
                    'Best price',
                    t.bestSellPrice == null
                        ? null
                        : 'KES ${_formatPriceCeil(t.bestSellPrice)}',
                  ),
                  _whoSection(ctx, t),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
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
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showWhoPathDialog(BuildContext context, CatalogTile t) async {
    final whoPath = (t.whoPath ?? '').trim();
    final whoAtcCode = (t.whoAtcCode ?? '').trim();
    final whoAtcName = (t.whoAtcName ?? '').trim();
    final whoPrimaryInn = (t.whoPrimaryInn ?? '').trim();
    final mappedInns = t.whoMappedInns ?? const <String>[];
    final atcLabels = t.whoAtcLabels ?? const <String>[];

    if (whoPath.isEmpty &&
        whoAtcCode.isEmpty &&
        whoAtcName.isEmpty &&
        mappedInns.isEmpty &&
        atcLabels.isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('WHO classification'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (whoAtcCode.isNotEmpty) ...[
                  Text(
                    'Primary ATC: $whoAtcCode${whoAtcName.isNotEmpty ? ' · $whoAtcName' : ''}',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (whoPrimaryInn.isNotEmpty) ...[
                  Text(
                    'Primary ingredient: $whoPrimaryInn',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                ],
                if (whoPath.isNotEmpty) ...[
                  SelectableText(
                    whoPath,
                    style: Theme.of(
                      ctx,
                    ).textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                ],
                if (mappedInns.isNotEmpty) ...[
                  Text(
                    'Mapped ingredients',
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mappedInns.join(', '),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                ],
                if (atcLabels.isNotEmpty) ...[
                  Text(
                    'Mapped ATC codes',
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...atcLabels.map(
                    (label) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        label,
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _whoSection(BuildContext context, CatalogTile t) {
    final whoPath = (t.whoPath ?? '').trim();
    final whoAtcCode = (t.whoAtcCode ?? '').trim();
    final whoAtcName = (t.whoAtcName ?? '').trim();
    final whoPrimaryInn = (t.whoPrimaryInn ?? '').trim();
    final mappedInns = t.whoMappedInns ?? const <String>[];
    final atcLabels = t.whoAtcLabels ?? const <String>[];

    if (whoPath.isEmpty &&
        whoAtcCode.isEmpty &&
        whoAtcName.isEmpty &&
        mappedInns.isEmpty &&
        atcLabels.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final preview = t.whoPathPreview?.trim().isNotEmpty == true
        ? t.whoPathPreview!.trim()
        : whoPath;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHO classification',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (whoAtcCode.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              whoAtcName.isNotEmpty
                  ? 'ATC: $whoAtcCode · $whoAtcName'
                  : 'ATC: $whoAtcCode',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (whoPrimaryInn.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Primary ingredient: $whoPrimaryInn',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(preview, style: theme.textTheme.bodyMedium),
          ],
          if (mappedInns.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Mapped ingredients: ${mappedInns.join(', ')}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (atcLabels.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Mapped ATCs: ${atcLabels.join(', ')}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showWhoPathDialog(context, t),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open full path'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(v, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
