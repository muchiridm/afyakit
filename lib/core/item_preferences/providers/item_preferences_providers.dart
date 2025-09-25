// lib/core/item_preferences/providers/item_preferences_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/token_provider.dart';
import 'package:afyakit/core/item_preferences/item_preferences_service.dart';
import 'package:afyakit/core/item_preferences/utils/item_preference_field.dart';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';

/// Service
final itemPreferenceServiceProvider = Provider<ItemPreferenceService>((ref) {
  final routes = ref.watch(apiRouteProvider);
  final token = ref.watch(tokenProvider);
  return ItemPreferenceService(routes, token);
});

/// Any preference field values (e.g. groups)
final preferenceValuesProvider =
    FutureProvider.family<
      List<String>,
      ({ItemType type, ItemPreferenceField field})
    >((ref, a) async {
      final svc = ref.watch(itemPreferenceServiceProvider);
      final values = await svc.fetchValues(a.type, a.field);
      values.sort((x, y) => x.toLowerCase().compareTo(y.toLowerCase()));
      return values;
    });

/// Convenience: “Group” values for a given item type
final groupsForTypeProvider = FutureProvider.family<List<String>, ItemType>((
  ref,
  type,
) async {
  final svc = ref.watch(itemPreferenceServiceProvider);
  final values = await svc.fetchValues(type, ItemPreferenceField.group);
  values.sort((x, y) => x.toLowerCase().compareTo(y.toLowerCase()));
  return values;
});
