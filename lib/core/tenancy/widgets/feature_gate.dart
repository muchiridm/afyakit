// lib/core/tenancy/widgets/feature_gate.dart

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/providers/tenant_feature_providers.dart';

class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    super.key,
    required this.featureKey,
    required this.child,
    this.fallback,
  });

  final String featureKey;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(isFeatureEnabledProvider(featureKey));
    return enabled ? child : (fallback ?? const SizedBox.shrink());
  }
}
