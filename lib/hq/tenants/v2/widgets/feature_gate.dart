// lib/hq/tenants/v2/widgets/feature_gate.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/v2/providers/tenant_profile_providers.dart';

class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.fallback,
  });

  final String feature;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(tenantProfileProvider);
    return asyncProfile.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => fallback ?? const SizedBox.shrink(),
      data: (p) {
        final enabled = p.features.features[feature] == true;
        if (!enabled) return fallback ?? const SizedBox.shrink();
        return child;
      },
    );
  }
}
