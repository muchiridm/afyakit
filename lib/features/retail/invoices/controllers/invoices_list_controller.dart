// lib/features/retail/invoices/controllers/invoices_list_controller.dart

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/state/paged_query_controller.dart';
import 'package:afyakit/features/retail/invoices/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/zoho_invoices_service.dart';

final invoicesListControllerProvider = StateNotifierProvider.autoDispose
    .family<
      InvoicesListController,
      PagedQueryState<ZohoInvoice>,
      RetailDocScope
    >((ref, scope) {
      final ctl = InvoicesListController(ref, scope: scope);
      ctl.refresh(reset: true);
      return ctl;
    });

class InvoicesListController extends PagedQueryController<ZohoInvoice> {
  InvoicesListController(this._ref, {required this.scope});

  final Ref _ref;
  final RetailDocScope scope;

  bool get _isMine => scope == RetailDocScope.mine;

  @override
  Future<PageResult<ZohoInvoice>> fetchPage({
    required String? q,
    required int page,
    required int limit,
  }) async {
    final svc = await _ref.read(zohoInvoicesServiceProvider.future);

    // Member scope must be hard-filtered by accountNumber.
    // If missing: fail closed (return empty).
    final me = _ref.read(currentUserValueProvider);
    final acct = (me?.accountNumber ?? '').trim();

    if (_isMine && acct.isEmpty) {
      return const PageResult(items: <ZohoInvoice>[], hasMore: false);
    }

    final qq = (q ?? '').trim();

    final items = await svc.list(
      limit: limit,
      page: page,
      q: qq.isEmpty ? null : qq,
      accountNumber: _isMine ? acct : null,
    );

    final hasMore = items.length == limit;
    return PageResult(items: items, hasMore: hasMore);
  }
}
