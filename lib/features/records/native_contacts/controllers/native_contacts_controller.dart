import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/native_contact.dart';
import '../services/native_contacts_service.dart';

/// First-page list only. Search in the current pilot is client-side.
final nativeContactsListProvider =
    FutureProvider.autoDispose<List<NativeContact>>((ref) async {
  final service = await ref.watch(nativeContactsServiceProvider.future);
  return service.list(perPage: 100);
});

class NativeContactsActionState {
  const NativeContactsActionState({this.busy = false, this.error});
  final bool busy;
  final String? error;
}

/// Controller owns mutations and cache invalidation; widgets own only form state.
class NativeContactsController extends StateNotifier<NativeContactsActionState> {
  NativeContactsController(this._service, this._invalidate)
      : super(const NativeContactsActionState());

  final Future<NativeContactsService> _service;
  final void Function() _invalidate;

  Future<void> refresh() async {
    _invalidate();
  }

  Future<bool> _mutate(Future<void> Function(NativeContactsService) action) async {
    if (state.busy) return false;
    state = const NativeContactsActionState(busy: true);
    try {
      final service = await _service;
      await action(service);
      _invalidate();
      if (mounted) state = const NativeContactsActionState();
      return true;
    } catch (e) {
      if (mounted) state = NativeContactsActionState(error: e.toString());
      return false;
    }
  }

  Future<bool> save(Map<String, Object?> values, {String? contactId}) =>
      _mutate((service) async {
        if (contactId == null) {
          await service.create(values);
        } else {
          await service.update(contactId, values);
        }
      });

  Future<bool> generateAccountNumber(String contactId) =>
      _mutate((service) async {
        await service.allocateAccountNumber(contactId);
      });

  Future<bool> removeFromApp(String contactId) =>
      _mutate((service) async {
        await service.removeFromApp(contactId);
      });
}

final nativeContactsControllerProvider = StateNotifierProvider.autoDispose<
    NativeContactsController, NativeContactsActionState>((ref) {
  final service = ref.watch(nativeContactsServiceProvider.future);
  return NativeContactsController(
    service,
    () => ref.invalidate(nativeContactsListProvider),
  );
});
