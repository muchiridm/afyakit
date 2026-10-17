import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:afyakit/shared/state/paged_query_controller.dart';
import 'package:afyakit/features/retail/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/services/zoho_invoices_service.dart';

final invoicesListControllerProvider = StateNotifierProvider.autoDispose
    .family<
      InvoicesListController,
      PagedQueryState<ZohoInvoice>,
      RetailDocScope
    >((ref, scope) {
      final controller = InvoicesListController(ref, scope: scope);
      controller.refresh(reset: true);
      return controller;
    });

class InvoicesListController extends PagedQueryController<ZohoInvoice> {
  InvoicesListController(this._ref, {required this.scope});

  final Ref _ref;
  final RetailDocScope scope;

  String? _searchQuery;

  bool get _isMine => scope == RetailDocScope.mine;

  String? get searchQuery => _searchQuery;

  void applySearch(String value) {
    final next = _clean(value);
    if (_searchQuery == next) return;

    _searchQuery = next;
    refresh(reset: true);
  }

  void clearSearch() {
    if (_searchQuery == null) return;

    _searchQuery = null;
    refresh(reset: true);
  }

  @override
  Future<PageResult<ZohoInvoice>> fetchPage({
    required String? q,
    required int page,
    required int limit,
  }) async {
    final service = await _ref.read(zohoInvoicesServiceProvider.future);

    final effectiveLimit = limit.clamp(1, 25).toInt();
    final search = _searchQuery ?? _clean(q);

    // Staff: retain the existing invoice directory behaviour.
    if (!_isMine) {
      final items = await service.list(
        limit: effectiveLimit,
        page: page,
        q: search,
      );

      return PageResult<ZohoInvoice>(
        items: items,
        hasMore: items.length == effectiveLimit,
      );
    }

    // Member: resolve the canonical account from authenticated state.
    // Do not query Zoho Contacts or retrieve accounting mappings.
    final accountNumber = _resolveMemberAccountNumber();

    if (accountNumber == null) {
      return const PageResult<ZohoInvoice>(
        items: <ZohoInvoice>[],
        hasMore: false,
      );
    }

    // The backend must enforce member ownership and resolve
    // the Native Contact -> Zoho customer mapping.
    final items = await service.list(
      limit: effectiveLimit,
      page: page,
      q: search,
      accountNumber: accountNumber,
    );

    return PageResult<ZohoInvoice>(
      items: items,
      hasMore: items.length == effectiveLimit,
    );
  }

  String? _resolveMemberAccountNumber() {
    final user = _ref.read(currentUserValueProvider);
    final accountNumber = _clean(user?.accountNumber);

    if (accountNumber == null) return null;

    final canonicalPattern = RegExp(
      r'^AC-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
    );

    if (!canonicalPattern.hasMatch(accountNumber)) {
      throw StateError('Invalid Native Contact account number');
    }

    return accountNumber;
  }

  static String? _clean(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }
}
