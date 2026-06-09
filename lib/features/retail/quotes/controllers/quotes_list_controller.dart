// lib/features/retail/quotes/controllers/quotes_list_controller.dart

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/features/retail/contacts/zoho_contacts_providers.dart';
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

  bool get _isMine => scope == RetailDocScope.mine;

  String? get searchQuery => _searchQuery;

  void applySearch(String value) {
    _searchQuery = _clean(value);
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

    // q is ignored because this app's PagedQueryController.refresh()
    // does not expose a q parameter. We keep the active query locally.
    final String? search = _searchQuery;

    if (!_isMine) {
      final List<ZohoQuote> items = await svc.list(
        limit: limit,
        page: page,
        q: search,
      );

      return PageResult<ZohoQuote>(
        items: items,
        hasMore: items.length == limit,
      );
    }

    final _MemberQuoteScope memberScope = _resolveMemberQuoteScope();

    if (!memberScope.hasScope) {
      return const PageResult<ZohoQuote>(items: <ZohoQuote>[], hasMore: false);
    }

    final List<ZohoQuote> items = await svc.list(
      limit: limit,
      page: page,
      q: search,

      // Prefer exact Zoho customer id.
      customerId: memberScope.customerId,

      // Fallback only if customerId is missing.
      accountNumber: memberScope.customerId == null
          ? memberScope.accountNumber
          : null,
    );

    return PageResult<ZohoQuote>(items: items, hasMore: items.length == limit);
  }

  _MemberQuoteScope _resolveMemberQuoteScope() {
    final ZohoMemberCustomerScope? zohoScope = _ref.read(
      zohoMemberCustomerScopeProvider,
    );

    final String? scopedCustomerId = _clean(zohoScope?.contactId);
    final String? scopedAccountNumber = _clean(zohoScope?.accountNumber);

    if (scopedCustomerId != null || scopedAccountNumber != null) {
      return _MemberQuoteScope(
        customerId: scopedCustomerId,
        accountNumber: scopedAccountNumber,
      );
    }

    final me = _ref.read(currentUserValueProvider);

    final String? userCustomerId = _clean(me?.zoho?.contactId);
    final String? userAccountNumber = _clean(me?.accountNumber);

    return _MemberQuoteScope(
      customerId: userCustomerId,
      accountNumber: userAccountNumber,
    );
  }

  static String? _clean(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }
}

class _MemberQuoteScope {
  const _MemberQuoteScope({this.customerId, this.accountNumber});

  final String? customerId;
  final String? accountNumber;

  bool get hasScope {
    return (customerId != null && customerId!.trim().isNotEmpty) ||
        (accountNumber != null && accountNumber!.trim().isNotEmpty);
  }
}
