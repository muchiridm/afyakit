// lib/hq/tenants/v2/controller/tenant_profile_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/v2/services/tenant_profile_service.dart';
import 'package:afyakit/hq/tenants/v2/extensions/tenant_status_x.dart';
import 'package:afyakit/hq/tenants/v2/providers/tenant_profile_stream_provider.dart';

class TenantProfileEditState {
  final bool busy;
  final String? error;

  const TenantProfileEditState({this.busy = false, this.error});

  TenantProfileEditState copyWith({bool? busy, String? error}) {
    return TenantProfileEditState(busy: busy ?? this.busy, error: error);
  }
}

final tenantProfileControllerProvider =
    AutoDisposeStateNotifierProvider<
      TenantProfileController,
      TenantProfileEditState
    >((ref) {
      return TenantProfileController(ref);
    });

class TenantProfileController extends StateNotifier<TenantProfileEditState> {
  TenantProfileController(this._ref) : super(const TenantProfileEditState());

  // ✅ correct ref type: <Notifier, State>
  final AutoDisposeStateNotifierProviderRef<
    TenantProfileController,
    TenantProfileEditState
  >
  _ref;

  Future<bool> save({
    String? slug,
    required String displayName,
    required String primaryColorHex,
    required Map<String, bool> features,
    required Map<String, dynamic> profile,
    TenantStatus status = TenantStatus.active,
  }) async {
    // service is a FutureProvider → await .future
    final svc = await _ref.read(tenantProfileServiceProvider.future);

    state = state.copyWith(busy: true, error: null);
    try {
      if (slug == null || slug.trim().isEmpty) {
        // create
        await svc.createTenantProfile(
          displayName: displayName,
          primaryColorHex: primaryColorHex,
          features: features,
          profile: profile,
          status: status,
        );
      } else {
        // update
        await svc.updateTenantProfile(
          slug: slug,
          displayName: displayName,
          primaryColorHex: primaryColorHex,
          features: features,
          profile: profile,
          status: status,
        );
      }

      // make the list tab refresh
      _ref.invalidate(tenantProfilesStreamProvider);

      state = state.copyWith(busy: false, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
      return false;
    }
  }
}
