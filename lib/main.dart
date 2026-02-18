// lib/main.dart

import 'package:afyakit/app/app_mode.dart';
import 'main_common.dart';

const kTenantSlug = String.fromEnvironment('TENANT', defaultValue: 'afyakit');

Future<void> main() async {
  final mode = AppModeX.fromEnv();
  await bootstrapAndRun(defaultTenantSlug: kTenantSlug, appMode: mode);
}
