import 'package:afyakit/features/inventory/records/issues/controllers/cart/cart_state.dart';

class MultiCartState {
  final Map<String, CartState> cartsByStore;

  const MultiCartState({required this.cartsByStore});

  factory MultiCartState.empty() => const MultiCartState(cartsByStore: {});

  CartState? cartFor(String storeId) => cartsByStore[storeId];

  bool get isEmpty =>
      cartsByStore.isEmpty || cartsByStore.values.every((c) => c.isEmpty);

  int get totalCartCount => cartsByStore.length;

  /// 🔢 Total quantity across all carts
  int get totalQuantity {
    return cartsByStore.values
        .map((c) => c.totalQuantity)
        .fold(0, (sum, qty) => sum + qty);
  }

  /// 🏪 A simple fallback for active store (first one in map)
  String? get activeStoreId {
    return cartsByStore.keys.isNotEmpty ? cartsByStore.keys.first : null;
  }

  MultiCartState copyWith({Map<String, CartState>? cartsByStore}) {
    return MultiCartState(cartsByStore: cartsByStore ?? this.cartsByStore);
  }
}
