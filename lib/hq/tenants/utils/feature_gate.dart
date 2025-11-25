// lib/hq/tenants/v2/utils/feature_gate.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/providers/tenant_profile_providers.dart';

bool isFeatureEnabled(WidgetRef ref, String key) {
  final asyncProfile = ref.watch(tenantProfileProvider);
  return asyncProfile.maybeWhen(
    data: (p) => p.features.features[key] == true,
    orElse: () => false,
  );
}
