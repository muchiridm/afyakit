// lib/features/retail/catalog/widgets/catalog_screen.dart

import 'dart:async';

import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/widgets/guest/guest_home_quick_actions.dart';
import 'package:afyakit/core/home/widgets/member/member_home_quick_action.dart';
import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_header.dart';
import 'package:afyakit/core/home/widgets/staff/staff_home_quick_actions.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/features/retail/catalog/controllers/catalog_controller.dart';
import 'package:afyakit/features/retail/catalog/models/catalog_models.dart';
import 'package:afyakit/features/retail/catalog/providers/catalog_providers.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_disclaimer.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_editor_screen.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/utils/app_error_message.dart';
import 'package:afyakit/shared/widgets/app_error_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'catalog_grid.dart';
import 'catalog_ui_bits.dart';

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
    this.entry = EntryMode.guest,
    this.user,
  });

  final String? initialQuery;
  final bool autofocusSearch;
  final EntryMode entry;
  final AuthUser? user;

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

    return state.query.q.trim().isEmpty;
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
        ctrl.refresh(
          query: state.query.copyWith(q: q, form: ''),
        );
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

  Future<void> _openQuoteEditor(BuildContext context) async {
    if (!mounted) return;

    await Navigator.of(context).push<QuoteEditorResult>(
      MaterialPageRoute<QuoteEditorResult>(
        builder: (_) => const QuoteEditorScreen(),
      ),
    );
  }

  void _addToQuote(
    BuildContext context,
    CatalogTile tile, {
    BuildContext? closeContext,
  }) {
    if (!mounted) return;

    ref.read(quoteLinesControllerProvider.notifier).addOrIncrement(tile);

    if (closeContext != null) {
      Navigator.of(closeContext).maybePop();
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Added to quote'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'VIEW',
          onPressed: () => _openQuoteEditor(context),
        ),
      ),
    );
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
        final QuoteLinesState quoteState = ref.watch(
          quoteLinesControllerProvider,
        );

        return AppPage(
          scrollable: true,
          maxWidth: 1100,
          header: HomeHeader(entry: widget.entry, showHomeButton: true),
          fab: _buildQuickActions(context),
          fabAlignment: Alignment.bottomRight,
          body: _buildBody(itemsAsync, state, quoteState),
        );
      },
    );
  }

  Widget _buildBody(
    AsyncValue<List<CatalogTile>> itemsAsync,
    CatalogState state,
    QuoteLinesState quoteState,
  ) {
    final CatalogController ctrl = ref.read(catalogControllerProvider.notifier);

    final bool showDiscovery = state.query.q.trim().isEmpty;

    final int? resultCount = showDiscovery
        ? null
        : itemsAsync.maybeWhen(
            data: (items) => items.length,
            orElse: () => null,
          );

    final bool hasActiveSearch = state.query.q.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),

        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SearchBarField(
              controller: _searchC,
              focusNode: _searchFocus,
              resultCount: resultCount,
              showClear: hasActiveSearch,
              helper: const CatalogDisclaimer(),
              onClear: () {
                if (!mounted) return;

                _searchC.clear();
                ctrl.refresh(query: const CatalogQuery());
              },
              onSubmit: (q) {
                if (!mounted) return;

                ctrl.refresh(
                  query: state.query.copyWith(q: q, form: ''),
                );
              },
              onChanged: (q) {
                if (!mounted) return;

                ctrl.refreshDebounced(
                  query: state.query.copyWith(q: q, form: ''),
                );
              },
            ),
          ),
        ),

        if (quoteState.isNotEmpty) ...[
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: _QuoteCartBanner(
                linesState: quoteState,
                onTap: () => _openQuoteEditor(context),
              ),
            ),
          ),
        ],

        if (!showDiscovery) ...[
          const SizedBox(height: 20),
          itemsAsync.when(
            loading: () => SkeletonGrid(scrollController: _scroll),
            error: (e, _) => AppErrorPane(
              title: 'Catalog temporarily unavailable',
              message: appErrorMessage(
                e,
                fallback:
                    'We could not load the catalog right now. Please try again shortly.',
              ),
              onRetry: ctrl.refresh,
            ),
            data: (items) => CatalogGrid(
              items: items,
              scrollController: _scroll,
              onTapTile: (tile) => _showTileSheet(context, tile),
              showTailLoader: state.hasMore,
              priceFormatter: _formatPriceCeil,
              priceColor: _priceGreen,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return switch (widget.entry) {
      EntryMode.member => MemberHomeQuickActions(
        key: ValueKey<String>(
          'catalog-member-quick-actions-'
          '${widget.user?.contactId ?? 'unknown'}',
        ),
        user: widget.user,
        onChat: () => _openChat(context),
      ),
      EntryMode.staff => StaffHomeQuickActions(
        key: const ValueKey<String>('catalog-staff-quick-actions'),
        onChat: () => _openChat(context),
      ),
      EntryMode.guest => GuestHomeQuickActions(
        key: const ValueKey<String>('catalog-guest-quick-actions'),
        onAuth: () => _openAuth(context),
        onChat: () => _openChat(context),
      ),
    };
  }

  void _openChat(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat navigation is not connected yet.')),
    );
  }

  Future<void> _openAuth(BuildContext context) async {
    final String tenantName = ref.read(tenantDisplayNameProvider);

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName)),
        fullscreenDialog: true,
      ),
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
                            _addToQuote(context, t, closeContext: ctx);
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
                        _addToQuote(context, t, closeContext: ctx);
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

class _QuoteCartBanner extends StatelessWidget {
  const _QuoteCartBanner({required this.linesState, required this.onTap});

  final QuoteLinesState linesState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final String itemText = linesState.itemCount == 1
        ? '1 item'
        : '${linesState.itemCount} items';

    final String lineText = linesState.lineCount == 1
        ? '1 line'
        : '${linesState.lineCount} lines';

    return Material(
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: colors.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$itemText in quote · $lineText',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'View quote',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: colors.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
