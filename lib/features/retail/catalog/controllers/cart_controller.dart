import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/catalog/catalog_models.dart';

@immutable
sealed class CartLine {
  const CartLine();

  String get key;
  int get qty;

  CartLine copyWithQty(int qty);
}

/// Normal catalog-backed line
@immutable
class CatalogCartLine extends CartLine {
  const CatalogCartLine({required this.tile, required this.qty});

  final CatalogTile tile;

  @override
  final int qty;

  @override
  String get key => 'tile:${tile.id}';

  @override
  CatalogCartLine copyWithQty(int qty) => CatalogCartLine(tile: tile, qty: qty);
}

/// Manual/custom line (not in catalog)
@immutable
class ManualCartLine extends CartLine {
  const ManualCartLine({
    required this.manualId,
    required this.name,
    this.description,
    required this.rate,
    required this.qty,
  });

  final String manualId; // stable id in cart
  final String name;
  final String? description;
  final num rate;

  @override
  final int qty;

  @override
  String get key => 'manual:$manualId';

  ManualCartLine copyWith({
    String? name,
    String? description,
    bool clearDescription = false,
    num? rate,
    int? qty,
  }) {
    final nextNameRaw = name ?? this.name;
    final nextNameTrim = nextNameRaw.trim();

    return ManualCartLine(
      manualId: manualId,
      name: nextNameTrim.isEmpty ? this.name : nextNameTrim,
      description: clearDescription ? null : (description ?? this.description),
      rate: rate ?? this.rate,
      qty: qty ?? this.qty,
    );
  }

  @override
  ManualCartLine copyWithQty(int qty) => copyWith(qty: qty);
}

@immutable
class CartState {
  const CartState({required this.lines});

  final List<CartLine> lines;

  const CartState.empty() : lines = const <CartLine>[];

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  int get lineCount => lines.length;

  int get itemCount {
    var n = 0;
    for (final l in lines) {
      n += l.qty;
    }
    return n;
  }

  int get missingPriceLineCount {
    var n = 0;
    for (final l in lines) {
      if (l is CatalogCartLine) {
        if (l.tile.bestSellPrice == null) n++;
      } else if (l is ManualCartLine) {
        if (l.rate <= 0) n++;
      }
    }
    return n;
  }

  bool get hasAllPrices => missingPriceLineCount == 0;

  num get estimatedTotal {
    num total = 0;
    for (final line in lines) {
      if (line is CatalogCartLine) {
        total += (line.tile.bestSellPrice ?? 0) * line.qty;
      } else if (line is ManualCartLine) {
        total += (line.rate) * line.qty;
      }
    }
    return total;
  }
}

class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState.empty());

  static const int _minQty = 1;
  static const int _maxQty = 9999;

  int _clampQty(int qty) => qty.clamp(_minQty, _maxQty);

  int _indexOfKey(String key) => state.lines.indexWhere((l) => l.key == key);

  /// Centralized state set: if list becomes empty, reset to CartState.empty()
  void _setLines(List<CartLine> nextLines) {
    if (nextLines.isEmpty) {
      state = const CartState.empty();
    } else {
      state = CartState(lines: List<CartLine>.unmodifiable(nextLines));
    }
  }

  // ───────────────────────── Catalog lines ─────────────────────────

  int getQty(CatalogTile tile) {
    final idx = _indexOfKey('tile:${tile.id}');
    if (idx == -1) return 0;
    return state.lines[idx].qty;
  }

  bool contains(CatalogTile tile) => _indexOfKey('tile:${tile.id}') != -1;

  void addOrIncrement(CatalogTile tile, {int delta = 1}) {
    final key = 'tile:${tile.id}';
    final idx = _indexOfKey(key);

    if (idx == -1) {
      final qty = _clampQty(delta < 1 ? 1 : delta);
      _setLines(<CartLine>[
        ...state.lines,
        CatalogCartLine(tile: tile, qty: qty),
      ]);
      return;
    }

    final current = state.lines[idx];
    final nextQty = _clampQty(current.qty + delta);
    if (nextQty == current.qty) return;

    final nextLines = [...state.lines];
    nextLines[idx] = current.copyWithQty(nextQty);
    _setLines(nextLines);
  }

  void setQtyForCatalog(CatalogTile tile, int qty) {
    final key = 'tile:${tile.id}';
    final idx = _indexOfKey(key);

    if (idx == -1) {
      if (qty > 0) {
        final safe = _clampQty(qty);
        _setLines(<CartLine>[
          ...state.lines,
          CatalogCartLine(tile: tile, qty: safe),
        ]);
      }
      return;
    }

    if (qty <= 0) {
      removeByKey(key); // will auto-clear if last line
      return;
    }

    final safe = _clampQty(qty);
    final current = state.lines[idx];
    if (safe == current.qty) return;

    final nextLines = [...state.lines];
    nextLines[idx] = current.copyWithQty(safe);
    _setLines(nextLines);
  }

  // ───────────────────────── Manual lines ─────────────────────────

  String addManualLine({
    required String name,
    String? description,
    required num rate,
    int qty = 1,
  }) {
    final safeName = name.trim().isEmpty ? 'Item' : name.trim();
    final safeRate = (rate.isNaN || rate.isInfinite || rate < 0) ? 0 : rate;
    final safeQty = _clampQty(qty < 1 ? 1 : qty);

    final id = 'm_${DateTime.now().microsecondsSinceEpoch}';

    final descTrim = (description ?? '').trim();
    _setLines(<CartLine>[
      ...state.lines,
      ManualCartLine(
        manualId: id,
        name: safeName,
        description: descTrim.isEmpty ? null : descTrim,
        rate: safeRate,
        qty: safeQty,
      ),
    ]);

    return id;
  }

  void updateManualLine(
    String manualId, {
    String? name,
    String? description,
    bool clearDescription = false,
    num? rate,
    int? qty,
  }) {
    final key = 'manual:${manualId.trim()}';
    final idx = _indexOfKey(key);
    if (idx == -1) return;

    final cur = state.lines[idx];
    if (cur is! ManualCartLine) return;

    final nextQty = qty == null ? cur.qty : _clampQty(qty < 1 ? 1 : qty);
    final nextRate = rate == null
        ? cur.rate
        : ((rate.isNaN || rate.isInfinite || rate < 0) ? 0 : rate);

    final nextName = name == null
        ? cur.name
        : (name.trim().isEmpty ? cur.name : name.trim());

    final nextDesc = clearDescription
        ? null
        : (description == null
              ? cur.description
              : (description.trim().isEmpty ? null : description.trim()));

    final nextLines = [...state.lines];
    nextLines[idx] = cur.copyWith(
      name: nextName,
      description: nextDesc,
      rate: nextRate,
      qty: nextQty,
      clearDescription: clearDescription,
    );

    _setLines(nextLines);
  }

  // ───────────────────────── Common ─────────────────────────

  void removeByKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return;

    final nextLines = state.lines
        .where((l) => l.key != k)
        .toList(growable: false);

    _setLines(nextLines); // if empty => CartState.empty()
  }

  void clear() {
    if (state.lines.isEmpty) return;
    state = const CartState.empty();
  }
}

// Provider
final cartControllerProvider = StateNotifierProvider<CartController, CartState>(
  (ref) => CartController(),
);
