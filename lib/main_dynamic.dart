import 'main_common.dart';

const kTenantSlug = String.fromEnvironment('TENANT', defaultValue: 'afyakit');

Future<void> main() async {
  await bootstrapAndRun(defaultTenantSlug: kTenantSlug);
}
