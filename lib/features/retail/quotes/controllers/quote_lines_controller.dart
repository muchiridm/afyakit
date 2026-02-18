// lib/features/retail/quotes/controllers/quote_lines_controller.dart

import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/catalog/catalog_models.dart';

@immutable
sealed class QuoteLine {
  const QuoteLine();

  String get key;
  int get qty;

  QuoteLine copyWithQty(int qty);
}

/// Catalog-backed line (tile id is stable)
/// Supports overrides for editing inside the quote editor.
@immutable
class CatalogQuoteLine extends QuoteLine {
  const CatalogQuoteLine({
    required this.tile,
    required this.qty,
    this.nameOverride,
    this.descriptionOverride,
    this.rateOverride,
  });

  final CatalogTile tile;

  /// Optional override for display + submission.
  /// If null/empty => fall back to tile fields.
  final String? nameOverride;

  /// Optional override for display + submission.
  /// If null/empty => fall back to tile fields.
  final String? descriptionOverride;

  /// Optional override for pricing in quote editor.
  /// If null => fall back to tile.bestSellPrice.
  final num? rateOverride;

  @override
  final int qty;

  @override
  String get key => 'tile:${tile.id}';

  // ───────────────────────── Effective values ─────────────────────────

  String get effectiveName {
    final o = (nameOverride ?? '').trim();
    if (o.isNotEmpty) return o;

    final t = (tile.tileTitle ?? '').trim();
    return t.isEmpty ? 'Item' : t;
  }

  String? get effectiveDescription {
    final o = (descriptionOverride ?? '').trim();
    if (o.isNotEmpty) return o;

    final d = (tile.tileDesc ?? '').trim();
    return d.isEmpty ? null : d;
  }

  num get effectiveRate => rateOverride ?? (tile.bestSellPrice ?? 0);

  // ───────────────────────── copyWith ─────────────────────────

  CatalogQuoteLine copyWith({
    CatalogTile? tile,
    int? qty,
    String? nameOverride,
    bool clearNameOverride = false,
    String? descriptionOverride,
    bool clearDescriptionOverride = false,
    num? rateOverride,
    bool clearRateOverride = false,
  }) {
    String? cleanStr(String? v) {
      final t = (v ?? '').trim();
      return t.isEmpty ? null : t;
    }

    final nextNameOverride = clearNameOverride
        ? null
        : (nameOverride == null ? this.nameOverride : cleanStr(nameOverride));

    final nextDescOverride = clearDescriptionOverride
        ? null
        : (descriptionOverride == null
              ? this.descriptionOverride
              : cleanStr(descriptionOverride));

    final nextRateOverride = clearRateOverride
        ? null
        : (rateOverride == null ? this.rateOverride : rateOverride);

    return CatalogQuoteLine(
      tile: tile ?? this.tile,
      qty: qty ?? this.qty,
      nameOverride: nextNameOverride,
      descriptionOverride: nextDescOverride,
      rateOverride: nextRateOverride,
    );
  }

  @override
  CatalogQuoteLine copyWithQty(int qty) => copyWith(qty: qty);
}

/// Manual/custom line (editor owned)
///
/// NOTE:
/// - manualId is local editor identity (stable in UI)
/// - zohoLineItemId is the Zoho line_item_id (present when editing existing quote)
@immutable
class ManualQuoteLine extends QuoteLine {
  const ManualQuoteLine({
    required this.manualId,
    required this.name,
    this.description,
    required this.rate,
    required this.qty,
    this.zohoLineItemId,
  });

  final String manualId;
  final String name;
  final String? description;
  final num rate;

  @override
  final int qty;

  /// Present when editing existing Zoho quote lines.
  /// If present, MUST be sent back as line_item_id to update the correct line.
  final String? zohoLineItemId;

  @override
  String get key => 'manual:$manualId';

  ManualQuoteLine copyWith({
    String? name,
    String? description,
    bool clearDescription = false,
    num? rate,
    int? qty,
    String? zohoLineItemId,
    bool clearZohoLineItemId = false,
  }) {
    final nextNameRaw = name ?? this.name;
    final nextNameTrim = nextNameRaw.trim();

    return ManualQuoteLine(
      manualId: manualId,
      name: nextNameTrim.isEmpty ? this.name : nextNameTrim,
      description: clearDescription ? null : (description ?? this.description),
      rate: rate ?? this.rate,
      qty: qty ?? this.qty,
      zohoLineItemId: clearZohoLineItemId
          ? null
          : (zohoLineItemId ?? this.zohoLineItemId),
    );
  }

  @override
  ManualQuoteLine copyWithQty(int qty) => copyWith(qty: qty);
}

@immutable
class QuoteLinesState {
  const QuoteLinesState({required this.lines});

  final List<QuoteLine> lines;

  const QuoteLinesState.empty() : lines = const <QuoteLine>[];

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
      if (l is CatalogQuoteLine) {
        if (l.effectiveRate <= 0) n++;
      } else if (l is ManualQuoteLine) {
        if (l.rate <= 0) n++;
      }
    }
    return n;
  }

  bool get hasAllPrices => missingPriceLineCount == 0;

  num get estimatedTotal {
    num total = 0;
    for (final line in lines) {
      if (line is CatalogQuoteLine) {
        total += line.effectiveRate * line.qty;
      } else if (line is ManualQuoteLine) {
        total += line.rate * line.qty;
      }
    }
    return total;
  }
}

class QuoteLinesController extends StateNotifier<QuoteLinesState> {
  QuoteLinesController() : super(const QuoteLinesState.empty());

  static const int _minQty = 1;
  static const int _maxQty = 9999;

  int _clampQty(int qty) => qty.clamp(_minQty, _maxQty);

  num _sanitizeRate(num rate) {
    if (rate.isNaN || rate.isInfinite || rate < 0) return 0;
    return rate;
  }

  int _indexOfKey(String key) => state.lines.indexWhere((l) => l.key == key);

  void _setLines(List<QuoteLine> nextLines) {
    if (nextLines.isEmpty) {
      state = const QuoteLinesState.empty();
    } else {
      state = QuoteLinesState(lines: List<QuoteLine>.unmodifiable(nextLines));
    }
  }

  void replaceAll(List<QuoteLine> lines) => _setLines(lines);

  // ───────────────────────── Catalog ─────────────────────────

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
      _setLines([...state.lines, CatalogQuoteLine(tile: tile, qty: qty)]);
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
    updateCatalogLine(tile, qty: qty);
  }

  /// Update existing catalog lines (name/desc/rate/qty) via overrides.
  void updateCatalogLine(
    CatalogTile tile, {
    String? name,
    String? description,
    num? rate,
    int? qty,
    bool clearName = false,
    bool clearDescription = false,
    bool clearRate = false,
  }) {
    final key = 'tile:${tile.id}';
    final idx = _indexOfKey(key);

    String? cleanStr(String? v) {
      final t = (v ?? '').trim();
      return t.isEmpty ? null : t;
    }

    final nextQty = qty == null ? null : _clampQty(qty < 1 ? 1 : qty);
    final nextRate = rate == null ? null : _sanitizeRate(rate);

    final nextName = name == null ? null : cleanStr(name);
    final nextDesc = description == null ? null : cleanStr(description);

    // Create if missing
    if (idx == -1) {
      final q = nextQty ?? 1;
      if (q <= 0) return;

      _setLines([
        ...state.lines,
        CatalogQuoteLine(
          tile: tile,
          qty: q,
          nameOverride: clearName ? null : nextName,
          descriptionOverride: clearDescription ? null : nextDesc,
          rateOverride: clearRate ? null : nextRate,
        ),
      ]);
      return;
    }

    final cur = state.lines[idx];
    if (cur is! CatalogQuoteLine) return;

    if (nextQty != null && nextQty <= 0) {
      removeByKey(key);
      return;
    }

    final updated = cur.copyWith(
      qty: nextQty ?? cur.qty,
      nameOverride: nextName,
      clearNameOverride: clearName,
      descriptionOverride: nextDesc,
      clearDescriptionOverride: clearDescription,
      rateOverride: nextRate,
      clearRateOverride: clearRate,
    );

    final nextLines = [...state.lines];
    nextLines[idx] = updated;
    _setLines(nextLines);
  }

  // ───────────────────────── Manual ─────────────────────────

  String addManualLine({
    required String name,
    String? description,
    required num rate,
    int qty = 1,
    String?
    zohoLineItemId, // optional: keep stable id when editing existing quotes
  }) {
    final safeName = name.trim().isEmpty ? 'Item' : name.trim();
    final safeRate = _sanitizeRate(rate);
    final safeQty = _clampQty(qty < 1 ? 1 : qty);

    final zohoId = (zohoLineItemId ?? '').trim();
    final id = zohoId.isNotEmpty
        ? zohoId
        : 'm_${DateTime.now().microsecondsSinceEpoch}';

    final descTrim = (description ?? '').trim();

    _setLines([
      ...state.lines,
      ManualQuoteLine(
        manualId: id,
        zohoLineItemId: zohoId.isEmpty ? null : zohoId,
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
    String? zohoLineItemId,
    bool clearZohoLineItemId = false,
  }) {
    final key = 'manual:${manualId.trim()}';
    final idx = _indexOfKey(key);
    if (idx == -1) return;

    final cur = state.lines[idx];
    if (cur is! ManualQuoteLine) return;

    final nextQty = qty == null ? cur.qty : _clampQty(qty < 1 ? 1 : qty);
    final nextRate = rate == null ? cur.rate : _sanitizeRate(rate);

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
      zohoLineItemId: zohoLineItemId,
      clearDescription: clearDescription,
      clearZohoLineItemId: clearZohoLineItemId,
    );

    _setLines(nextLines);
  }

  // ───────────────────────── Zoho Edit Hydration ─────────────────────────

  /// ✅ Critical: when editing an existing Zoho quote, treat ALL Zoho lines as ManualQuoteLine
  /// using line_item_id as stable identity so overrides persist and updates target the right line.
  void loadFromZohoQuote(ZohoQuote q) {
    final next = <QuoteLine>[];

    for (final li in q.lineItems) {
      final zohoId = (li.lineItemId ?? '').trim();
      final manualId = zohoId.isNotEmpty
          ? zohoId
          : 'm_${DateTime.now().microsecondsSinceEpoch}';

      final nm = li.name.trim().isEmpty ? 'Item' : li.name.trim();
      final desc = (li.description ?? '').trim();
      final qty = li.quantity.round() < 1 ? 1 : li.quantity.round();

      next.add(
        ManualQuoteLine(
          manualId: manualId,
          zohoLineItemId: zohoId.isEmpty ? null : zohoId,
          name: nm,
          description: desc.isEmpty ? null : desc,
          rate: _sanitizeRate(li.rate),
          qty: _clampQty(qty),
        ),
      );
    }

    replaceAll(next);
  }

  /// Build Zoho-ready line_items maps.
  /// - ManualQuoteLine sends line_item_id when present (updates)
  /// - CatalogQuoteLine sends effective name/desc/rate (creates)
  List<Map<String, Object?>> toZohoLineItems() {
    final out = <Map<String, Object?>>[];

    for (final l in state.lines) {
      if (l is ManualQuoteLine) {
        final m = <String, Object?>{
          'name': l.name,
          'quantity': l.qty,
          'rate': _sanitizeRate(l.rate),
        };

        final d = (l.description ?? '').trim();
        if (d.isNotEmpty) m['description'] = d;

        final id = (l.zohoLineItemId ?? '').trim();
        if (id.isNotEmpty) m['line_item_id'] = id;

        out.add(m);
      } else if (l is CatalogQuoteLine) {
        final m = <String, Object?>{
          'name': l.effectiveName,
          'quantity': l.qty,
          'rate': _sanitizeRate(l.effectiveRate),
        };

        final d = (l.effectiveDescription ?? '').trim();
        if (d.isNotEmpty) m['description'] = d;

        out.add(m);
      }
    }

    return out;
  }

  // ───────────────────────── Common ─────────────────────────

  void removeByKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return;

    final nextLines = state.lines
        .where((l) => l.key != k)
        .toList(growable: false);

    _setLines(nextLines);
  }

  void clear() {
    if (state.lines.isEmpty) return;
    state = const QuoteLinesState.empty();
  }
}

final quoteLinesControllerProvider =
    StateNotifierProvider<QuoteLinesController, QuoteLinesState>(
      (ref) => QuoteLinesController(),
    );
