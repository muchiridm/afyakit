import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/hq/tenants/providers/tenant_profiles_stream_provider.dart';
import 'package:afyakit/features/hq/tenants/services/tenant_admin_service.dart';
import 'package:afyakit/core/tenancy/extensions/tenant_status_x.dart';

class TenantProfileEditState {
  final bool busy;
  final String? error;

  const TenantProfileEditState({this.busy = false, this.error});

  TenantProfileEditState copyWith({bool? busy, String? error}) {
    return TenantProfileEditState(
      busy: busy ?? this.busy,
      // always replace error (can be null to clear)
      error: error,
    );
  }
}

final tenantProfileControllerProvider =
    AutoDisposeStateNotifierProvider<
      TenantProfileController,
      TenantProfileEditState
    >((ref) => TenantProfileController(ref));

class TenantProfileController extends StateNotifier<TenantProfileEditState> {
  TenantProfileController(this.ref) : super(const TenantProfileEditState());

  final Ref ref;

  Future<bool> save({
    String? slug,
    required String displayName,
    required String primaryColorHex,
    required Map<String, bool> features,
    required Map<String, dynamic> profile,
    Map<String, dynamic>? assets,
    TenantStatus status = TenantStatus.active,
  }) async {
    final svc = await ref.read(tenantAdminServiceProvider.future);

    state = state.copyWith(busy: true, error: null);
    try {
      if (slug == null || slug.trim().isEmpty) {
        await svc.createTenantProfile(
          displayName: displayName,
          primaryColorHex: primaryColorHex,
          features: features,
          profile: profile,
          assets: assets ?? const {},
          status: status,
        );
      } else {
        await svc.updateTenantProfile(
          slug: slug,
          displayName: displayName,
          primaryColorHex: primaryColorHex,
          features: features,
          profile: profile,
          assets: assets,
          status: status,
        );
      }

      ref.invalidate(tenantProfilesStreamProvider);

      state = state.copyWith(busy: false, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String slug) async {
    final svc = await ref.read(tenantAdminServiceProvider.future);

    state = state.copyWith(busy: true, error: null);
    try {
      await svc.deleteTenantProfile(slug, hard: true);

      ref.invalidate(tenantProfilesStreamProvider);

      state = state.copyWith(busy: false, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
      return false;
    }
  }
}
