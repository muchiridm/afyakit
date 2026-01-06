// lib/core/item_preferences/providers/item_preferences_providers.dart
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/providers.dart'; // afyakitClientProvider
import 'package:afyakit/core/api/afyakit/routes.dart';

import 'package:afyakit/features/inventory/preferences/item_preferences_service.dart';
import 'package:afyakit/features/inventory/preferences/utils/item_preference_field.dart';
import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';

// ─────────────────────────────────────────────────────────
// Service (async): routes + Dio from AfyaKitClient
// ─────────────────────────────────────────────────────────
final itemPreferenceServiceProvider = FutureProvider<ItemPreferenceService>((
  ref,
) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final client = await ref.watch(afyakitClientProvider.future);
  return ItemPreferenceService(
    routes: AfyaKitRoutes(tenantId),
    dio: client.dio,
  );
});

// ─────────────────────────────────────────────────────────
// Any preference field values (e.g., groups)
// ─────────────────────────────────────────────────────────
final preferenceValuesProvider =
    FutureProvider.family<
      List<String>,
      ({ItemType type, ItemPreferenceField field})
    >((ref, a) async {
      final svc = await ref.watch(itemPreferenceServiceProvider.future);
      final values = await svc.fetchValues(a.type, a.field);
      values.sort((x, y) => x.toLowerCase().compareTo(y.toLowerCase()));
      return values;
    });

// ─────────────────────────────────────────────────────────
// Convenience: “Group” values for a given item type
// ─────────────────────────────────────────────────────────
final groupsForTypeProvider = FutureProvider.family<List<String>, ItemType>((
  ref,
  type,
) async {
  final svc = await ref.watch(itemPreferenceServiceProvider.future);
  final values = await svc.fetchValues(type, ItemPreferenceField.group);
  values.sort((x, y) => x.toLowerCase().compareTo(y.toLowerCase()));
  return values;
});
