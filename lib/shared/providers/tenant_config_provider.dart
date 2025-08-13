import 'package:afyakit/shared/tenant/tenant_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tenantConfigProvider = Provider<TenantConfig>((ref) {
  throw UnimplementedError(
    'tenantConfigProvider must be overridden at bootstrap',
  );
});
