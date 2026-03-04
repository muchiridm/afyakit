// lib/core/tenancy/widgets/feature_gate.dart

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/tenants/providers/tenant_feature_providers.dart';

class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    super.key,
    required this.featureKey,
    required this.child,
    this.fallback,
    this.loading,
  });

  final String featureKey;
  final Widget child;
  final Widget? fallback;

  /// Optional: what to show while tenant profile is still resolving.
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Provider returns `true` while loading (see tenant_feature_providers.dart),
    // so we rarely need loading here — but keep it as a hook.
    final enabled = ref.watch(isFeatureEnabledProvider(featureKey));

    if (enabled) return child;
    return fallback ?? loading ?? const SizedBox.shrink();
  }
}
