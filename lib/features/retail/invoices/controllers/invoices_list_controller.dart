import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/features/retail/contacts/services/zoho_contacts_service.dart';
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

    final effectiveLimit = limit > 25 ? 25 : limit;
    final search = _searchQuery;

    // Staff listing: retain the existing invoice directory behaviour.
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

    // Member listing: authenticated Native Contact -> verified Zoho mapping.
    final customerId = await _resolveMemberZohoCustomerId();

    if (customerId == null) {
      return const PageResult<ZohoInvoice>(
        items: <ZohoInvoice>[],
        hasMore: false,
      );
    }

    final items = await service.list(
      limit: effectiveLimit,
      page: page,
      q: search,
      customerId: customerId,
    );

    return PageResult<ZohoInvoice>(
      items: items,
      hasMore: items.length == effectiveLimit,
    );
  }

  Future<String?> _resolveMemberZohoCustomerId() async {
    final user = _ref.read(currentUserValueProvider);

    final nativeContactId = _clean(user?.nativeContactId);

    if (nativeContactId == null) {
      return null;
    }

    final zohoService = await _ref.read(zohoContactsServiceProvider.future);

    final mapping = await zohoService.getMapping(nativeContactId);

    return _clean(mapping.zohoContactId);
  }

  static String? _clean(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }
}
