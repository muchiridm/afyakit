import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import '../services/mpesa_service.dart';

typedef PaymentContext = ({
  String? uid,
  String tenant,
  String app,
  bool active,
});

final paymentContextProvider = Provider<PaymentContext>((ref) {
  final tenant = ref.watch(tenantIdProvider);
  final app = ref.watch(appIdProvider);
  final firebase = ref.watch(firebaseUserProvider).asData?.value;
  final user = ref.watch(currentUserProvider).asData?.value;
  return (
    uid: firebase?.uid,
    tenant: tenant,
    app: app,
    active:
        firebase != null &&
        user != null &&
        user.uid == firebase.uid &&
        user.tenantId == tenant &&
        !user.isDisabled &&
        user.hasActiveAppMembership(app),
  );
});

final mpesaEligibilityProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, invoiceId) async {
      final context = ref.watch(paymentContextProvider);
      if (!context.active ||
          context.tenant != 'afya' ||
          context.app != 'dawapap')
        return false;
      final service = await ref.watch(mpesaServiceProvider.future);
      return service.isEligible(invoiceId);
    });
