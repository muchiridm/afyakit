// lib/features/retail/quotes/controllers/quote_editor_state.dart

import 'package:afyakit/features/retail/quotes/extensions/quote_editor_mode_x.dart';
import 'package:afyakit/features/retail/quotes/models/di_sales_tile.dart';
import 'package:afyakit/features/retail/quotes/models/quote_draft.dart';

class QuoteEditorState {
  const QuoteEditorState({
    this.mode = QuoteEditorMode.create,
    this.quoteId,

    // Preview/edit header context (from backend quote)
    this.customerId,
    this.customerName,
    this.currencyCode,

    this.loadingCatalog = false,
    this.loadingQuote = false,
    this.savingQuote = false,
    this.error,
    this.q = '',
    this.items = const <DiSalesTile>[],
    this.offset = 0,
    this.nextOffset,
    this.draft = const QuoteDraft(),
  });

  final QuoteEditorMode mode;
  final String? quoteId;

  /// Backend quote fields useful for preview/edit without requiring ZohoContact hydration.
  /// - In create mode, these are typically null (until you create).
  /// - In preview/edit, they come from GET /quotes/:id (estimate).
  final String? customerId;
  final String? customerName;
  final String? currencyCode;

  final bool loadingCatalog;
  final bool loadingQuote;
  final bool savingQuote;
  final String? error;

  final String q;
  final List<DiSalesTile> items;
  final int offset;
  final int? nextOffset;

  final QuoteDraft draft;

  bool get hasMore => nextOffset != null;

  /// Best-effort display label for the customer across modes.
  /// - Preview/edit uses customerName (from backend).
  /// - Create uses picked contact (draft.contact).
  String get customerLabel {
    final fromBackend = (customerName ?? '').trim();
    if (fromBackend.isNotEmpty) return fromBackend;

    final fromDraft = (draft.contact?.displayName ?? '').trim();
    if (fromDraft.isNotEmpty) return fromDraft;

    return 'Customer';
  }

  QuoteEditorState copyWith({
    QuoteEditorMode? mode,
    String? quoteId,
    bool clearQuoteId = false,

    String? customerId,
    String? customerName,
    String? currencyCode,
    bool clearCustomer = false,

    bool? loadingCatalog,
    bool? loadingQuote,
    bool? savingQuote,

    /// If you pass null, error becomes null (clears it).
    String? error,

    String? q,
    List<DiSalesTile>? items,
    int? offset,
    int? nextOffset,
    bool clearNextOffset = false,

    QuoteDraft? draft,
  }) {
    return QuoteEditorState(
      mode: mode ?? this.mode,
      quoteId: clearQuoteId ? null : (quoteId ?? this.quoteId),

      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      currencyCode: clearCustomer ? null : (currencyCode ?? this.currencyCode),

      loadingCatalog: loadingCatalog ?? this.loadingCatalog,
      loadingQuote: loadingQuote ?? this.loadingQuote,
      savingQuote: savingQuote ?? this.savingQuote,

      error: error, // explicit, same pattern as your original

      q: q ?? this.q,
      items: items ?? this.items,
      offset: offset ?? this.offset,
      nextOffset: clearNextOffset ? null : (nextOffset ?? this.nextOffset),
      draft: draft ?? this.draft,
    );
  }
}
