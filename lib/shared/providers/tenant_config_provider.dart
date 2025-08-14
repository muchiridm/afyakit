// shared/providers/tenant_config_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/config/tenant_config.dart';

final tenantConfigProvider = Provider<TenantConfig>((ref) {
  throw UnimplementedError('Override me in main()');
});

// 👉 derived provider only exposes the string, so fewer widgets rebuild
final tenantDisplayNameProvider = Provider<String>(
  (ref) => ref.watch(tenantConfigProvider).displayName,
);
