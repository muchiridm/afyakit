// lib/features/retail/payments/controllers/payments_by_invoice_controller.dart

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/features/retail/contacts/providers/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/services/zoho_invoices_service.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:afyakit/shared/state/paged_query_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentsByInvoiceControllerProvider = StateNotifierProvider.autoDispose
    .family<
      PaymentsByInvoiceController,
      PagedQueryState<ZohoInvoice>,
      RetailDocScope
    >((ref, scope) {
      final PaymentsByInvoiceController ctl = PaymentsByInvoiceController(
        ref,
        scope: scope,
      );

      ctl.refresh(reset: true);

      return ctl;
    });

class PaymentsByInvoiceController extends PagedQueryController<ZohoInvoice> {
  PaymentsByInvoiceController(this._ref, {required this.scope});

  static const int _maxPageSize = 25;

  final Ref _ref;
  final RetailDocScope scope;

  String? _searchQuery;

  bool get _isMine => scope == RetailDocScope.mine;

  String? get searchQuery => _searchQuery;

  bool get hasSearch => _searchQuery != null;

  void applySearch(String value) {
    final String? next = _clean(value);

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
    final ZohoInvoicesService svc = await _ref.read(
      zohoInvoicesServiceProvider.future,
    );

    final String? search = _searchQuery ?? _clean(q);
    final int effectiveLimit = limit > _maxPageSize ? _maxPageSize : limit;

    if (!_isMine) {
      final List<ZohoInvoice> items = await svc.list(
        limit: effectiveLimit,
        page: page,
        q: search,
      );

      return PageResult<ZohoInvoice>(
        items: items,
        hasMore: items.length == effectiveLimit,
      );
    }

    final _MemberInvoiceScope memberScope = _resolveMemberInvoiceScope();

    if (!memberScope.hasScope) {
      return const PageResult<ZohoInvoice>(
        items: <ZohoInvoice>[],
        hasMore: false,
      );
    }

    final List<ZohoInvoice> items = await svc.list(
      limit: effectiveLimit,
      page: page,
      q: search,
      customerId: memberScope.customerId,
      accountNumber: memberScope.customerId == null
          ? memberScope.accountNumber
          : null,
    );

    return PageResult<ZohoInvoice>(
      items: items,
      hasMore: items.length == effectiveLimit,
    );
  }

  _MemberInvoiceScope _resolveMemberInvoiceScope() {
    final ZohoMemberCustomerScope? zohoScope = _ref.read(
      zohoMemberCustomerScopeProvider,
    );

    final String? scopedCustomerId = _clean(zohoScope?.contactId);
    final String? scopedAccountNumber = _clean(zohoScope?.accountNumber);

    if (scopedCustomerId != null || scopedAccountNumber != null) {
      return _MemberInvoiceScope(
        customerId: scopedCustomerId,
        accountNumber: scopedAccountNumber,
      );
    }

    final me = _ref.read(currentUserValueProvider);

    return _MemberInvoiceScope(accountNumber: _clean(me?.accountNumber));
  }

  static String? _clean(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }
}

class _MemberInvoiceScope {
  const _MemberInvoiceScope({this.customerId, this.accountNumber});

  final String? customerId;
  final String? accountNumber;

  bool get hasScope {
    return _hasText(customerId) || _hasText(accountNumber);
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
