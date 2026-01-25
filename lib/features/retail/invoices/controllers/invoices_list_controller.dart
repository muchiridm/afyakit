import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/state/paged_query_controller.dart';

import 'package:afyakit/features/retail/shared/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/services/zoho_invoices_service.dart';

final invoicesListControllerProvider =
    StateNotifierProvider.autoDispose<
      InvoicesListController,
      PagedQueryState<ZohoInvoice>
    >((ref) {
      final ctl = InvoicesListController(ref);
      ctl.refresh(reset: true);
      return ctl;
    });

class InvoicesListController extends PagedQueryController<ZohoInvoice> {
  InvoicesListController(this._ref);

  final Ref _ref;

  @override
  Future<PageResult<ZohoInvoice>> fetchPage({
    required String? q,
    required int page,
    required int limit,
  }) async {
    final svc = await _ref.read(zohoInvoicesServiceProvider.future);
    final items = await svc.list(limit: limit, page: page);

    final hasMore = items.length == limit;
    return PageResult(items: items, hasMore: hasMore);
  }
}
