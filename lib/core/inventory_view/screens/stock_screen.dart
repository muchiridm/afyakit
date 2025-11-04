// lib/features/src/inventory_view/screens/stock_screen.dart

import 'package:afyakit/core/inventory_view/widgets/inventory_speed_dial.dart';
import 'package:afyakit/core/records/issues/controllers/cart/multi_cart_controller.dart';
import 'package:afyakit/core/records/issues/controllers/cart/multi_cart_state.dart';
import 'package:afyakit/core/records/issues/widgets/cart_drawer.dart';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/inventory_view/controllers/inventory_view_controller.dart';
import 'package:afyakit/core/inventory_view/utils/inventory_mode_enum.dart';
import 'package:afyakit/core/inventory_view/widgets/inventory_browser_components/inventory_browser.dart';
import 'package:afyakit/shared/widgets/base_screen.dart';
import 'package:afyakit/shared/widgets/screen_header/screen_header.dart';
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
  late TabController _tabController;
  final List<ItemType> _types = ItemType.values
      .where((t) => t != ItemType.unknown)
      .toList();

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

    return Scaffold(
      floatingActionButton: widget.mode.isStockIn
          ? InventorySpeedDial(
              onAdd: (type) {
                final controller = ref.read(
                  inventoryViewControllerFamily(type).notifier,
                );
                controller.createItem(context);
              },
            )
          : null,
      body: BaseScreen(
        maxContentWidth: 1000,
        scrollable: false,
        endDrawer: isStockOut ? const CartDrawer(action: 'dispense') : null,
        header: _buildHeader(multiCart),
        body: _buildTabBarView(multiCart),
      ),
    );
  }

  Widget _buildHeader(MultiCartState multiCart) {
    final total = multiCart.totalQuantity;

    return Column(
      children: [
        ScreenHeader(
          widget.mode.label,
          trailing: isStockOut
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.shopping_cart),
                        tooltip: 'View Cart',
                        onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                      ),
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
      children: _types.map((type) {
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
          batchQuantities: activeCart?.batchQuantities ?? {},
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
      }).toList(),
    );
  }

  String _capitalize(String text) =>
      text[0].toUpperCase() + text.substring(1).toLowerCase();
}
