// lib/features/retail/quotes/controllers/quotes_list_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/state/paged_query_controller.dart';

import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/services/zoho_quotes_service.dart';

final quotesListControllerProvider =
    StateNotifierProvider.autoDispose<
      QuotesListController,
      PagedQueryState<ZohoQuote>
    >((ref) {
      final ctl = QuotesListController(ref);
      ctl.refresh(reset: true);
      return ctl;
    });

class QuotesListController extends PagedQueryController<ZohoQuote> {
  QuotesListController(this._ref);

  final Ref _ref;

  @override
  Future<PageResult<ZohoQuote>> fetchPage({
    required String? q,
    required int page,
    required int limit,
  }) async {
    final svc = await _ref.read(zohoQuotesServiceProvider.future);
    final items = await svc.list(limit: limit, page: page);

    final hasMore = items.length == limit;
    return PageResult(items: items, hasMore: hasMore);
  }
}
