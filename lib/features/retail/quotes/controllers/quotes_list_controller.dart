// lib/features/retail/quotes/controllers/quotes_list_controller.dart

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
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

  bool get _isMine => scope == RetailDocScope.mine;

  @override
  Future<PageResult<ZohoQuote>> fetchPage({
    required String? q,
    required int page,
    required int limit,
  }) async {
    final svc = await _ref.read(zohoQuotesServiceProvider.future);

    // Member scope must be hard-filtered by accountNumber.
    // If missing: fail closed (return empty).
    final me = _ref.read(currentUserValueProvider);
    final acct = (me?.accountNumber ?? '').trim();

    if (_isMine && acct.isEmpty) {
      return const PageResult(items: <ZohoQuote>[], hasMore: false);
    }

    final items = await svc.list(
      limit: limit,
      page: page,
      q: (q ?? '').trim().isEmpty ? null : q!.trim(),
      // ✅ only apply this when mine
      accountNumber: _isMine ? acct : null,
    );

    final hasMore = items.length == limit;
    return PageResult(items: items, hasMore: hasMore);
  }
}
