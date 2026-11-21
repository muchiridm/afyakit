// lib/features/retail/quotes/controllers/quotes_list_controller.dart

import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/services/zoho_quotes_service.dart';
import 'package:afyakit/shared/state/paged_query_controller.dart';

final quotesListControllerProvider = StateNotifierProvider.autoDispose
    .family<QuotesListController, PagedQueryState<ZohoQuote>, RetailDocScope>((
      ref,
      scope,
    ) {
      final ctl = QuotesListController(ref, scope: scope);
      ctl.refresh(reset: true);
      return ctl;
    });

class QuotesListController extends PagedQueryController<ZohoQuote> {
  QuotesListController(this._ref, {required this.scope});

  final Ref _ref;
  final RetailDocScope scope;
  String? _searchQuery;

  String? get searchQuery => _searchQuery;

  void applySearch(String value) {
    final text = value.trim();
    _searchQuery = text.isEmpty ? null : text;
    refresh(reset: true);
  }

  void clearSearch() {
    _searchQuery = null;
    refresh(reset: true);
  }

  @override
  Future<PageResult<ZohoQuote>> fetchPage({
    required String? q,
    required int page,
    required int limit,
  }) async {
    final ZohoQuotesService svc = await _ref.read(
      zohoQuotesServiceProvider.future,
    );

    // The backend enforces the member's authenticated Native Contact scope.
    // Do not provide legacy Zoho IDs or unverified account numbers from Flutter.
    final List<ZohoQuote> items = await svc.list(
      limit: limit,
      page: page,
      q: _searchQuery,
    );

    return PageResult<ZohoQuote>(items: items, hasMore: items.length == limit);
  }
}
