import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'item_preference.dart';
import 'item_preferences_service.dart';

final itemPreferencesServiceProvider =
    FutureProvider.autoDispose<ItemPreferencesService>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  ref.watch(appIdProvider); // Rebuild when the app context changes.
  final client = await ref.watch(afyakitClientFutureProvider.future);
  return ItemPreferencesService(dio: client.dio, routes: AfyaKitRoutes(tenantId));
});

final itemPreferenceValuesProvider =
    FutureProvider.autoDispose.family<List<String>, ItemPreferenceKey>((ref, key) async {
  final service = await ref.watch(itemPreferencesServiceProvider.future);
  final values = await service.get(key.itemType, key.field);
  return values..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
});
