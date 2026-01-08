// lib/features/retail/quotes/controllers/quote_editor_engine.dart

import '../extensions/quote_editor_mode_x.dart';
import '../models/di_sales_tile.dart';
import '../models/quote_draft.dart';
import '../services/di_sales_service.dart';
import '../services/zoho_quotes_service.dart';
import 'quote_hydrator.dart';

class QuoteCatalogPage {
  const QuoteCatalogPage({
    required this.items,
    required this.offset,
    required this.nextOffset,
  });

  final List<DiSalesTile> items;
  final int offset;
  final int? nextOffset;
}

sealed class QuoteSaveOutcome {
  const QuoteSaveOutcome();
}

class QuoteSaveOk extends QuoteSaveOutcome {
  const QuoteSaveOk({required this.updated});
  final bool updated;
}

class QuoteSaveFailed extends QuoteSaveOutcome {
  const QuoteSaveFailed(this.message);
  final String message;
}

class QuoteEditorEngine {
  const QuoteEditorEngine({
    required this.quotes,
    required this.sales,
    required this.hydrator,
  });

  final ZohoQuotesService quotes;
  final DiSalesService sales;
  final QuoteHydrator hydrator;

  Future<HydratedQuote> loadQuoteForEdit(String quoteId) async {
    final data = await quotes.getQuote(quoteId);
    return hydrator.fromBackendQuote(data);
  }

  Future<QuoteCatalogPage> searchCatalog({
    required String? q,
    required int limit,
    required int offset,
  }) async {
    final page = await sales.search(q: q, limit: limit, offset: offset);

    // If your sales.search() is correctly typed, page.items is already List<DiSalesTile>.
    // If it's not, fix it there—don't cast here.
    return QuoteCatalogPage(
      items: page.items,
      offset: page.offset,
      nextOffset: page.nextOffset,
    );
  }

  Future<QuoteSaveOutcome> save({
    required QuoteEditorMode mode,
    required String? quoteId,
    required QuoteDraft draft,
  }) async {
    try {
      if (mode == QuoteEditorMode.edit) {
        final id = (quoteId ?? '').trim();
        if (id.isEmpty) {
          return const QuoteSaveFailed('Missing quoteId for edit mode');
        }
        await quotes.updateQuoteFromDraft(id, draft);
        return const QuoteSaveOk(updated: true);
      }

      await quotes.createQuoteFromDraft(draft);
      return const QuoteSaveOk(updated: false);
    } catch (e) {
      return QuoteSaveFailed(e.toString());
    }
  }
}
