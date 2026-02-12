// lib/features/src/inventory_view/screens/stock_screen.dart

import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/features/inventory/records/issues/controllers/cart/multi_cart_controller.dart';
import 'package:afyakit/features/inventory/records/issues/controllers/cart/multi_cart_state.dart';
import 'package:afyakit/features/inventory/records/issues/widgets/cart_drawer.dart';
import 'package:afyakit/features/inventory/views/controllers/inventory_view_controller.dart';
import 'package:afyakit/features/inventory/views/utils/inventory_mode_enum.dart';
import 'package:afyakit/features/inventory/views/widgets/inventory_browser_components/inventory_browser.dart';
import 'package:afyakit/features/inventory/views/widgets/inventory_speed_dial.dart';
import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StockScreen extends ConsumerStatefulWidget {
  final InventoryMode mode;

  const StockScreen({super.key, required this.mode});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ✅ Ensures the header cart button opens the correct endDrawer
  final GlobalKey<ScaffoldState> _shellScaffoldKey = GlobalKey<ScaffoldState>();

  final List<ItemType> _types = ItemType.values
      .where((t) => t != ItemType.unknown)
      .toList(growable: false);

  bool get isStockOut => widget.mode.isStockOut;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _types.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiCart = ref.watch(multiCartProvider);

    return AppPage(
      scrollable: false,
      maxWidth: 1000,

      // keep the page header constrained to the same width as body
      header: _buildHeader(context, multiCart),

      // keep drawer behavior exactly as before (StockOut -> cart drawer)
      // AppPage doesn't have an endDrawer slot, so we wrap it with a Scaffold.
      body: _ScaffoldShell(
        scaffoldKey: _shellScaffoldKey,
        endDrawer: isStockOut ? const CartDrawer(action: 'dispense') : null,
        fab: widget.mode.isStockIn
            ? InventorySpeedDial(
                onAdd: (type) {
                  final controller = ref.read(
                    inventoryViewControllerFamily(type).notifier,
                  );
                  controller.createItem(context);
                },
              )
            : null,
        child: _buildTabBarView(multiCart),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, MultiCartState multiCart) {
    final total = multiCart.totalQuantity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppHeader(
          title: widget.mode.label,
          // AppHeader already supplies back by default; keep it consistent
          trailing: isStockOut
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart),
                      tooltip: 'View Cart',
                      onPressed: () =>
                          _shellScaffoldKey.currentState?.openEndDrawer(),
                    ),
                    if (total > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.teal,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              total > 99 ? '99+' : '$total',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : null,
        ),
        TabBar(
          controller: _tabController,
          tabs: _types.map((t) => Tab(text: _capitalize(t.name))).toList(),
        ),
      ],
    );
  }

  Widget _buildTabBarView(MultiCartState multiCart) {
    return TabBarView(
      controller: _tabController,
      children: _types
          .map((type) {
            final state = ref.watch(inventoryViewControllerFamily(type));
            final controller = ref.read(
              inventoryViewControllerFamily(type).notifier,
            );

            final userStore = multiCart.activeStoreId;
            final activeCart = userStore != null
                ? multiCart.cartFor(userStore)
                : null;

            return InventoryBrowser(
              key: ValueKey('${widget.mode.name}-${type.name}'),
              type: type,
              mode: widget.mode,
              enableSelectionCart: isStockOut,
              showBatches: true,
              batchQuantities: activeCart?.batchQuantities ?? const {},
              items: state.items,
              matcher: state.matcher?.map ?? const {},
              query: state.query,
              sortAscending: state.sortAscending,
              isLoading: state.isLoading,
              error: state.error,
              onQueryChanged: controller.setQuery,
              onSortToggle: controller.toggleSort,
              onQtyChange: isStockOut
                  ? (itemId, batchId, qty) {
                      if (userStore != null) {
                        ref
                            .read(multiCartProvider.notifier)
                            .updateQuantity(
                              itemId: itemId,
                              batchId: batchId,
                              qty: qty,
                              storeId: userStore,
                              itemType: type,
                            );
                      }
                    }
                  : null,
              onAddToCart: null,
            );
          })
          .toList(growable: false),
    );
  }

  String _capitalize(String text) => text.isEmpty
      ? text
      : text[0].toUpperCase() + text.substring(1).toLowerCase();
}

/// Tiny wrapper so we can keep `endDrawer` + FAB behavior even though AppPage
/// returns its own Scaffold.
class _ScaffoldShell extends StatelessWidget {
  const _ScaffoldShell({
    required this.child,
    required this.scaffoldKey,
    this.endDrawer,
    this.fab,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget child;
  final Widget? endDrawer;
  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.transparent, // let AppPage own page background
      endDrawer: endDrawer,
      floatingActionButton: fab,
      body: child,
    );
  }
}
