// lib/hq/super_admins/hq_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/super_admins/hq_api_client.dart';

final hqApiClientProvider = Provider<HqApiClient>((ref) {
  // Prefer a dart-define or your existing config
  const coreBase = String.fromEnvironment(
    'AFYAKIT_CORE_BASE', // e.g. https://api.afyakit.app/core
    defaultValue: 'https://your-backend.example.com/core',
  );
  final base = Uri.parse(coreBase).resolve('hq');
  return HqApiClient(base: base);
});
