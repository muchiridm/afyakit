// lib/features/retail/quotes/controllers/quote_hydrator.dart

import '../models/di_sales_tile.dart';
import '../models/quote_draft.dart';

class HydratedQuote {
  const HydratedQuote({
    required this.draft,
    required this.customerId,
    required this.customerName,
    required this.currencyCode,
  });

  final QuoteDraft draft;
  final String? customerId;
  final String? customerName;
  final String? currencyCode;
}

/// Hydrates editor state from your backend quote shape.
/// Supports variations in line item keys so preview/edit totals remain correct.
class QuoteHydrator {
  const QuoteHydrator();

  HydratedQuote fromBackendQuote(Map<String, dynamic> j) {
    String? _s(Object? v) {
      if (v == null) return null;
      final t = v.toString().trim();
      return t.isEmpty ? null : t;
    }

    num? _numN(Object? v) {
      if (v == null) return null;
      if (v is num) return v;
      if (v is String) return num.tryParse(v.trim());
      return null;
    }

    int? _intN(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
      return null;
    }

    Object? _first(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        if (m.containsKey(k) && m[k] != null) return m[k];
      }
      return null;
    }

    final customerId = _s(j['customer_id']);
    final customerName = _s(j['customer_name']);
    final currencyCode = _s(j['currency_code']);

    // Some backends use different header keys
    final reference = _s(j['reference_number']) ?? _s(j['reference']);
    final notes = _s(j['notes']) ?? _s(j['customer_notes']);

    final rawItems = j['line_items'];
    final lines = <QuoteLineDraft>[];

    if (rawItems is List) {
      for (final v in rawItems) {
        if (v is! Map) continue;
        final m = v.cast<String, dynamic>();

        final name =
            _s(_first(m, ['name', 'item_name', 'product_name'])) ?? 'Item';
        final desc = _s(_first(m, ['description', 'desc']));

        // Qty: handle key variations
        final qtyRaw = _first(m, ['quantity', 'qty']);
        final qty = _intN(qtyRaw) ?? 1;
        final safeQty = qty < 1 ? 1 : qty;

        // Rate: handle key variations
        final rateRaw = _first(m, ['rate', 'unit_rate', 'unit_price', 'price']);
        num rate = _numN(rateRaw) ?? 0;

        // Amount: sometimes provided instead of rate
        final amountRaw = _first(m, [
          'amount',
          'item_total',
          'line_total',
          'total',
        ]);
        final amount = _numN(amountRaw);

        // If rate missing/zero but amount exists, derive rate
        if (rate <= 0 && amount != null && safeQty > 0) {
          rate = amount / safeQty;
        }

        final safeRate = rate < 0 ? 0 : rate;

        final tile = DiSalesTile(
          canonKey: name, // stable enough for draft merge & display
          groupKey: name,
          tileTitle: name,
          tileDesc: desc,
          form: null,
          bestPackCount: null,
          offerCount: 0,
          bestSellPrice: safeRate,
          bestSupplier: null,
          priceRequestRequired: null,
        );

        lines.add(
          QuoteLineDraft(tile: tile, quantity: safeQty, rate: safeRate),
        );
      }
    }

    final draft = QuoteDraft(
      contact: null, // keep null in edit/preview; UI uses state.customerLabel
      reference: reference,
      customerNotes: notes,
      lines: lines,
    );

    return HydratedQuote(
      draft: draft,
      customerId: customerId,
      customerName: customerName,
      currencyCode: currencyCode,
    );
  }
}
