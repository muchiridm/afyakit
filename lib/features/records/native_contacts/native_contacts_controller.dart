import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/native_contacts_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';

/// First-page list only.
/// Search in the current pilot is client-side.
final nativeContactsListProvider =
    FutureProvider.autoDispose<List<NativeContact>>((ref) async {
      final service = await ref.watch(nativeContactsServiceProvider.future);

      return service.list(perPage: 100);
    });

/// Staff-only linked Profile summaries. Scoped to the canonical account ID.
final contactLinkedProfilesProvider = FutureProvider.autoDispose.family<List<Profile>, String>((ref, accountNumber) async {
  final service = await ref.watch(nativeContactsServiceProvider.future);
  return service.listLinkedHealthProfiles(accountNumber);
});

class NativeContactsActionState {
  const NativeContactsActionState({this.busy = false, this.error});

  final bool busy;
  final String? error;
}

/// Controller owns mutations and cache invalidation.
/// Widgets own only form state.
class NativeContactsController
    extends StateNotifier<NativeContactsActionState> {
  NativeContactsController(this._service, this._invalidate, this._invalidateLinks)
    : super(const NativeContactsActionState());

  final Future<NativeContactsService> _service;
  final void Function() _invalidate;
  final void Function() _invalidateLinks;

  Future<bool> linkProfile({required String accountNumber, required String profileId, required ProfileContactRelationship relationship}) =>
      _mutate((service) async { await service.linkHealthProfile(accountNumber: accountNumber, profileId: profileId, relationship: relationship); });

  Future<bool> changeProfileLink({required String accountNumber, required String profileId, required ProfileContactRelationship relationship}) =>
      _mutate((service) async { await service.updateHealthProfileLink(accountNumber: accountNumber, profileId: profileId, relationship: relationship); });

  Future<bool> unlinkProfile({required String accountNumber, required String profileId}) =>
      _mutate((service) async { await service.unlinkHealthProfile(accountNumber: accountNumber, profileId: profileId); });

  Future<void> refresh() async {
    _invalidate();
  }

  Future<bool> _mutate(
    Future<void> Function(NativeContactsService) action,
  ) async {
    if (state.busy) return false;

    state = const NativeContactsActionState(busy: true);

    try {
      final service = await _service;

      await action(service);

      _invalidate();
      _invalidateLinks();

      if (mounted) {
        state = const NativeContactsActionState();
      }

      return true;
    } catch (error) {
      if (mounted) {
        state = NativeContactsActionState(error: error.toString());
      }

      return false;
    }
  }

  /// Creates a new Native Contact or updates an existing one.
  ///
  /// New Contacts automatically receive an AC-XXXXXX account number
  /// from the backend.
  Future<bool> save(Map<String, Object?> values, {String? accountNumber}) =>
      _mutate((service) async {
        if (accountNumber == null) {
          await service.create(values);
        } else {
          await service.update(accountNumber, values);
        }
      });

  /// Removes membership in the current app.
  /// Does not delete the tenant-wide Native Contact.
  Future<bool> removeFromApp(String accountNumber) => _mutate((service) async {
    await service.removeFromApp(accountNumber);
  });
}

final nativeContactsControllerProvider =
    StateNotifierProvider.autoDispose<
      NativeContactsController,
      NativeContactsActionState
    >((ref) {
      final service = ref.watch(nativeContactsServiceProvider.future);

      return NativeContactsController(
        service,
        () => ref.invalidate(nativeContactsListProvider),
        () => ref.invalidate(contactLinkedProfilesProvider),
      );
    });
