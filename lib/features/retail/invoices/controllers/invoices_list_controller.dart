// lib/features/retail/invoices/controllers/invoices_list_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/retail/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/services/zoho_invoices_service.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:afyakit/shared/state/paged_query_controller.dart';

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

  static const int _maxPageSize = 25;

  final Ref _ref;
  final RetailDocScope scope;

  String? _searchQuery;

  bool get _isMine => scope == RetailDocScope.mine;

  String? get searchQuery => _searchQuery;

  bool get hasSearch => _searchQuery != null;

  void applySearch(String value) {
    final next = _clean(value);
    if (_searchQuery == next) return;

    _searchQuery = next;
    refresh(reset: true);
  }

  void clearSearch() => applySearch('');

  @override
  Future<PageResult<ZohoInvoice>> fetchPage({
    required String? q,
    required int page,
    required int limit,
  }) async {
    final accountNumber = _isMine ? _resolveMemberAccountNumber() : null;

    if (_isMine && accountNumber == null) {
      return const PageResult<ZohoInvoice>(
        items: <ZohoInvoice>[],
        hasMore: false,
      );
    }

    final service = await _ref.read(zohoInvoicesServiceProvider.future);

    final effectiveLimit = limit.clamp(1, _maxPageSize).toInt();

    final items = await service.list(
      limit: effectiveLimit,
      page: page,
      q: _searchQuery ?? _clean(q),
      accountNumber: accountNumber,
    );

    return PageResult<ZohoInvoice>(
      items: items,
      hasMore: items.length == effectiveLimit,
    );
  }

  String? _resolveMemberAccountNumber() {
    final user = _ref.read(currentUserValueProvider);
    final raw = _clean(user?.accountNumber);

    if (raw == null) return null;

    final accountNumber = NativeContact.requireAccountNumber(raw);

    if (!accountNumber.startsWith('AC-')) {
      throw StateError('Member accounts must belong to a person.');
    }

    return accountNumber;
  }

  static String? _clean(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }
}
