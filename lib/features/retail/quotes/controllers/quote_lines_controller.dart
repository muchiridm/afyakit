import 'dart:math';

import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/catalog/models/catalog_models.dart';

const String kZohoDeliveryServiceItemId = '7052134000001200001';
const String kDeliveryChargeDefaultName = 'Delivery Charge';
const String kDeliveryChargeDefaultDescription = 'Shipment to customer address';

@immutable
sealed class QuoteLine {
  const QuoteLine();

  String get key;
  int get qty;

  QuoteLine copyWithQty(int qty);
}

/// Catalog-backed line (tile id is stable)
/// Supports overrides for editing inside the quote editor.
///
/// IMPORTANT:
/// - Default cart behavior: merge by tile.id (lineId == null)
/// - Once overrides are applied (name/desc/rate), we PROMOTE the line into a unique
///   identity (lineId != null) so multiple catalog lines with different edits do NOT merge.
@immutable
class CatalogQuoteLine extends QuoteLine {
  const CatalogQuoteLine({
    required this.tile,
    required this.qty,
    this.nameOverride,
    this.descriptionOverride,
    this.rateOverride,
    this.lineId,
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

  /// If set, this catalog line becomes unique and no longer merges
  /// with other lines for the same tile.
  final String? lineId;

  @override
  final int qty;

  @override
  String get key =>
      lineId == null ? 'tile:${tile.id}' : 'tile:${tile.id}:$lineId';

  String get effectiveName {
    final String o = (nameOverride ?? '').trim();
    if (o.isNotEmpty) return o;

    final String t = (tile.tileTitle ?? '').trim();
    return t.isEmpty ? 'Item' : t;
  }

  String? get effectiveDescription {
    final String o = (descriptionOverride ?? '').trim();
    if (o.isNotEmpty) return o;

    final String d = (tile.tileDesc ?? '').trim();
    return d.isEmpty ? null : d;
  }

  num get effectiveRate => rateOverride ?? (tile.bestSellPrice ?? 0);

  bool get hasOverrides {
    final String n = (nameOverride ?? '').trim();
    final String d = (descriptionOverride ?? '').trim();
    return n.isNotEmpty || d.isNotEmpty || rateOverride != null;
  }

  CatalogQuoteLine copyWith({
    CatalogTile? tile,
    int? qty,
    String? nameOverride,
    bool clearNameOverride = false,
    String? descriptionOverride,
    bool clearDescriptionOverride = false,
    num? rateOverride,
    bool clearRateOverride = false,
    String? lineId,
    bool clearLineId = false,
  }) {
    String? cleanStr(String? v) {
      final String t = (v ?? '').trim();
      return t.isEmpty ? null : t;
    }

    final String? nextNameOverride = clearNameOverride
        ? null
        : (nameOverride == null ? this.nameOverride : cleanStr(nameOverride));

    final String? nextDescOverride = clearDescriptionOverride
        ? null
        : (descriptionOverride == null
              ? this.descriptionOverride
              : cleanStr(descriptionOverride));

    final num? nextRateOverride = clearRateOverride
        ? null
        : (rateOverride ?? this.rateOverride);

    final String? nextLineId = clearLineId ? null : (lineId ?? this.lineId);

    return CatalogQuoteLine(
      tile: tile ?? this.tile,
      qty: qty ?? this.qty,
      nameOverride: nextNameOverride,
      descriptionOverride: nextDescOverride,
      rateOverride: nextRateOverride,
      lineId: nextLineId,
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
/// - zohoItemId links the line to a Zoho product/service item
@immutable
class ManualQuoteLine extends QuoteLine {
  const ManualQuoteLine({
    required this.manualId,
    required this.name,
    this.description,
    required this.rate,
    required this.qty,
    this.zohoLineItemId,
    this.zohoItemId,
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

  /// Optional link to a Zoho product/service item.
  final String? zohoItemId;

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
    String? zohoItemId,
    bool clearZohoItemId = false,
  }) {
    final String nextNameRaw = name ?? this.name;
    final String nextNameTrim = nextNameRaw.trim();

    return ManualQuoteLine(
      manualId: manualId,
      name: nextNameTrim.isEmpty ? this.name : nextNameTrim,
      description: clearDescription ? null : (description ?? this.description),
      rate: rate ?? this.rate,
      qty: qty ?? this.qty,
      zohoLineItemId: clearZohoLineItemId
          ? null
          : (zohoLineItemId ?? this.zohoLineItemId),
      zohoItemId: clearZohoItemId ? null : (zohoItemId ?? this.zohoItemId),
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
    int n = 0;
    for (final QuoteLine l in lines) {
      n += l.qty;
    }
    return n;
  }

  int get missingPriceLineCount {
    int n = 0;
    for (final QuoteLine l in lines) {
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
    for (final QuoteLine line in lines) {
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

  final Random _rng = Random.secure();
  int _seq = 0;

  int _clampQty(int qty) => qty.clamp(_minQty, _maxQty);

  num _sanitizeRate(num rate) {
    if (rate.isNaN || rate.isInfinite || rate < 0) return 0;
    return rate;
  }

  int _indexOfKey(String key) =>
      state.lines.indexWhere((QuoteLine l) => l.key == key);

  void _setLines(List<QuoteLine> nextLines) {
    if (nextLines.isEmpty) {
      state = const QuoteLinesState.empty();
    } else {
      state = QuoteLinesState(lines: List<QuoteLine>.unmodifiable(nextLines));
    }
  }

  void replaceAll(List<QuoteLine> lines) => _setLines(lines);

  String _newId(String prefix) {
    _seq = (_seq + 1) % 1000000;
    final int t = DateTime.now().microsecondsSinceEpoch;
    final int r = _rng.nextInt(1 << 31);
    return '${prefix}_${t}_${_seq}_$r';
  }

  String _newManualId() => _newId('m');
  String _newCatalogLineId() => _newId('c');

  int getQty(CatalogTile tile) {
    final int idx = state.lines.indexWhere((QuoteLine l) {
      if (l is! CatalogQuoteLine) return false;
      return l.tile.id == tile.id && l.lineId == null;
    });
    if (idx == -1) return 0;
    return state.lines[idx].qty;
  }

  bool contains(CatalogTile tile) {
    return state.lines.any((QuoteLine l) {
      if (l is! CatalogQuoteLine) return false;
      return l.tile.id == tile.id && l.lineId == null;
    });
  }

  void addOrIncrement(CatalogTile tile, {int delta = 1}) {
    final int idx = state.lines.indexWhere((QuoteLine l) {
      if (l is! CatalogQuoteLine) return false;
      return l.tile.id == tile.id && l.lineId == null;
    });

    if (idx == -1) {
      final int qty = _clampQty(delta < 1 ? 1 : delta);
      _setLines(<QuoteLine>[
        ...state.lines,
        CatalogQuoteLine(tile: tile, qty: qty),
      ]);
      return;
    }

    final CatalogQuoteLine current = state.lines[idx] as CatalogQuoteLine;
    final int nextQty = _clampQty(current.qty + delta);
    if (nextQty == current.qty) return;

    final List<QuoteLine> nextLines = <QuoteLine>[...state.lines];
    nextLines[idx] = current.copyWithQty(nextQty);
    _setLines(nextLines);
  }

  void setQtyForCatalog(CatalogTile tile, int qty) {
    updateCatalogLine(tile, qty: qty);
  }

  void updateCatalogLine(
    CatalogTile tile, {
    String? lineKey,
    String? lineId,
    String? name,
    String? description,
    num? rate,
    int? qty,
    bool clearName = false,
    bool clearDescription = false,
    bool clearRate = false,
  }) {
    int idx = -1;

    final String k = (lineKey ?? '').trim();
    final String lid = (lineId ?? '').trim();

    if (k.isNotEmpty) {
      idx = _indexOfKey(k);
    } else if (lid.isNotEmpty) {
      idx = state.lines.indexWhere((QuoteLine l) {
        if (l is! CatalogQuoteLine) return false;
        return l.tile.id == tile.id && (l.lineId ?? '') == lid;
      });
    } else {
      idx = state.lines.indexWhere((QuoteLine l) {
        if (l is! CatalogQuoteLine) return false;
        return l.tile.id == tile.id && l.lineId == null;
      });
    }

    String? cleanStr(String? v) {
      final String t = (v ?? '').trim();
      return t.isEmpty ? null : t;
    }

    final int? nextQty = qty == null ? null : _clampQty(qty < 1 ? 1 : qty);
    final num? nextRate = rate == null ? null : _sanitizeRate(rate);

    final String? nextName = name == null ? null : cleanStr(name);
    final String? nextDesc = description == null ? null : cleanStr(description);

    if (idx == -1) {
      if (k.isNotEmpty || lid.isNotEmpty) {
        return;
      }

      final int q = nextQty ?? 1;
      if (q <= 0) return;

      var created = CatalogQuoteLine(
        tile: tile,
        qty: q,
        nameOverride: clearName ? null : nextName,
        descriptionOverride: clearDescription ? null : nextDesc,
        rateOverride: clearRate ? null : nextRate,
        lineId: null,
      );

      if (created.hasOverrides) {
        created = created.copyWith(lineId: _newCatalogLineId());
      }

      _setLines(<QuoteLine>[...state.lines, created]);
      return;
    }

    final QuoteLine cur = state.lines[idx];
    if (cur is! CatalogQuoteLine) return;

    if (nextQty != null && nextQty <= 0) {
      removeByKey(cur.key);
      return;
    }

    var updated = cur.copyWith(
      qty: nextQty ?? cur.qty,
      nameOverride: nextName,
      clearNameOverride: clearName,
      descriptionOverride: nextDesc,
      clearDescriptionOverride: clearDescription,
      rateOverride: nextRate,
      clearRateOverride: clearRate,
    );

    if (updated.lineId == null && updated.hasOverrides) {
      updated = updated.copyWith(lineId: _newCatalogLineId());
    }

    final List<QuoteLine> nextLines = <QuoteLine>[...state.lines];
    nextLines[idx] = updated;
    _setLines(nextLines);
  }

  String addManualLine({
    required String name,
    String? description,
    required num rate,
    int qty = 1,
    String? zohoLineItemId,
    String? zohoItemId,
  }) {
    final String safeName = name.trim().isEmpty ? 'Item' : name.trim();
    final num safeRate = _sanitizeRate(rate);
    final int safeQty = _clampQty(qty < 1 ? 1 : qty);

    final String zohoId = (zohoLineItemId ?? '').trim();
    final String itemId = (zohoItemId ?? '').trim();
    final String id = zohoId.isNotEmpty ? zohoId : _newManualId();

    final String descTrim = (description ?? '').trim();

    _setLines(<QuoteLine>[
      ...state.lines,
      ManualQuoteLine(
        manualId: id,
        zohoLineItemId: zohoId.isEmpty ? null : zohoId,
        zohoItemId: itemId.isEmpty ? null : itemId,
        name: safeName,
        description: descTrim.isEmpty ? null : descTrim,
        rate: safeRate,
        qty: safeQty,
      ),
    ]);

    return id;
  }

  String addDeliveryChargeLine({
    num rate = 0,
    int qty = 1,
    String name = kDeliveryChargeDefaultName,
    String? description = kDeliveryChargeDefaultDescription,
  }) {
    return addManualLine(
      name: name,
      description: description,
      qty: qty,
      rate: rate,
      zohoItemId: kZohoDeliveryServiceItemId,
    );
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
    String? zohoItemId,
    bool clearZohoItemId = false,
  }) {
    final String key = 'manual:${manualId.trim()}';
    final int idx = _indexOfKey(key);
    if (idx == -1) return;

    final QuoteLine cur = state.lines[idx];
    if (cur is! ManualQuoteLine) return;

    final int nextQty = qty == null ? cur.qty : _clampQty(qty < 1 ? 1 : qty);
    final num nextRate = rate == null ? cur.rate : _sanitizeRate(rate);

    final String nextName = name == null
        ? cur.name
        : (name.trim().isEmpty ? cur.name : name.trim());

    final String? nextDesc = clearDescription
        ? null
        : (description == null
              ? cur.description
              : (description.trim().isEmpty ? null : description.trim()));

    final List<QuoteLine> nextLines = <QuoteLine>[...state.lines];
    nextLines[idx] = cur.copyWith(
      name: nextName,
      description: nextDesc,
      rate: nextRate,
      qty: nextQty,
      zohoLineItemId: zohoLineItemId,
      clearDescription: clearDescription,
      clearZohoLineItemId: clearZohoLineItemId,
      zohoItemId: zohoItemId,
      clearZohoItemId: clearZohoItemId,
    );

    _setLines(nextLines);
  }

  void loadFromZohoQuote(ZohoQuote q) {
    final List<QuoteLine> next = <QuoteLine>[];

    for (final ZohoQuoteLineItem li in q.lineItems) {
      final String zohoId = (li.lineItemId ?? '').trim();
      final String manualId = zohoId.isNotEmpty ? zohoId : _newManualId();

      final String nm = li.name.trim().isEmpty ? 'Item' : li.name.trim();
      final String desc = (li.description ?? '').trim();
      final int qty = li.quantity.round() < 1 ? 1 : li.quantity.round();

      next.add(
        ManualQuoteLine(
          manualId: manualId,
          zohoLineItemId: zohoId.isEmpty ? null : zohoId,
          zohoItemId: null,
          name: nm,
          description: desc.isEmpty ? null : desc,
          rate: _sanitizeRate(li.rate),
          qty: _clampQty(qty),
        ),
      );
    }

    replaceAll(next);
  }

  List<Map<String, Object?>> toZohoLineItems() {
    final List<Map<String, Object?>> out = <Map<String, Object?>>[];

    for (final QuoteLine l in state.lines) {
      if (l is ManualQuoteLine) {
        final Map<String, Object?> m = <String, Object?>{
          'name': l.name,
          'quantity': l.qty,
          'rate': _sanitizeRate(l.rate),
        };

        final String d = (l.description ?? '').trim();
        if (d.isNotEmpty) m['description'] = d;

        final String lineId = (l.zohoLineItemId ?? '').trim();
        if (lineId.isNotEmpty) m['line_item_id'] = lineId;

        final String itemId = (l.zohoItemId ?? '').trim();
        if (itemId.isNotEmpty) m['item_id'] = itemId;

        out.add(m);
      } else if (l is CatalogQuoteLine) {
        final Map<String, Object?> m = <String, Object?>{
          'name': l.effectiveName,
          'quantity': l.qty,
          'rate': _sanitizeRate(l.effectiveRate),
        };

        final String d = (l.effectiveDescription ?? '').trim();
        if (d.isNotEmpty) m['description'] = d;

        out.add(m);
      }
    }

    return out;
  }

  void removeByKey(String key) {
    final String k = key.trim();
    if (k.isEmpty) return;

    final List<QuoteLine> nextLines = state.lines
        .where((QuoteLine l) => l.key != k)
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
      (Ref ref) => QuoteLinesController(),
    );
