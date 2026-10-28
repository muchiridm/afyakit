import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hq_tenant_contacts_providers.dart';
import 'hq_tenant_contacts_service.dart';

class HqContactActionState {
  const HqContactActionState({this.busy = false, this.error});
  final bool busy;
  final String? error;
}

class HqTenantContactsController extends StateNotifier<HqContactActionState> {
  HqTenantContactsController(this.ref) : super(const HqContactActionState());
  final Ref ref;

  Future<bool> _perform(String tenantId, Future<void> Function(HqTenantContactsService) task) async {
    if (state.busy) return false;
    state = const HqContactActionState(busy: true);
    try {
      final service = await ref.read(hqTenantContactsServiceProvider.future);
      await task(service);
      ref.invalidate(hqTenantContactsProvider(tenantId));
      if (mounted) state = const HqContactActionState();
      return true;
    } catch (error) {
      if (mounted) state = HqContactActionState(error: error.toString());
      return false;
    }
  }

  Future<bool> create(String tenantId, Map<String, Object?> data) =>
      _perform(tenantId, (service) async { await service.create(tenantId, data); });

  Future<bool> update(String tenantId, String accountNumber, Map<String, Object?> data) =>
      _perform(tenantId, (service) async {
        await service.update(tenantId, accountNumber, data);
        ref.invalidate(hqTenantContactProvider((tenantId: tenantId, accountNumber: accountNumber)));
      });

  Future<bool> archive(String tenantId, String accountNumber, String reason) =>
      _perform(tenantId, (service) async { await service.archive(tenantId, accountNumber, reason: reason); });

  Future<bool> restore(String tenantId, String accountNumber, String reason) =>
      _perform(tenantId, (service) async { await service.restore(tenantId, accountNumber, reason: reason); });

  Future<bool> permanentlyDelete(String tenantId, String accountNumber, String reason) =>
      _perform(tenantId, (service) async {
        await service.permanentlyDelete(tenantId, accountNumber, reason: reason);
        ref.invalidate(hqTenantContactProvider((tenantId: tenantId, accountNumber: accountNumber)));
        ref.invalidate(hqTenantContactDependenciesProvider((tenantId: tenantId, accountNumber: accountNumber)));
      });

}

final hqTenantContactsControllerProvider = StateNotifierProvider.autoDispose<
    HqTenantContactsController, HqContactActionState>((ref) => HqTenantContactsController(ref));
