// lib/main.dart

import 'package:afyakit/app/app_mode.dart';
import 'main_common.dart';

const _envTenant = String.fromEnvironment('TENANT', defaultValue: '');

String _requireTenant(String label) {
  final t = _envTenant.trim().toLowerCase();
  if (t.isEmpty) {
    throw StateError(
      'Missing TENANT for $label. Run with --dart-define=TENANT=<slug>',
    );
  }
  return t;
}

Future<void> main() async {
  final mode = AppModeX.fromEnv();

  final defaultTenantSlug = switch (mode) {
    AppMode.hq => _requireTenant('HQ'), // usually "hq"
    AppMode.tenant =>
      _envTenant.trim().isNotEmpty
          ? _envTenant.trim().toLowerCase()
          : 'afyakit',
  };

  await bootstrapAndRun(defaultTenantSlug: defaultTenantSlug, appMode: mode);
}
