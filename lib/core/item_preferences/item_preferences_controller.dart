// lib/core/item_preferences/item_preference_controller_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/api/afyakit/providers.dart'; // afyakitClientProvider
import 'package:afyakit/api/afyakit/routes.dart';
import 'package:afyakit/hq/tenants/v2/providers/tenant_slug_provider.dart';

import 'package:afyakit/core/item_preferences/utils/item_preference_field.dart';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/item_preferences/item_preferences_service.dart';

/// 🧩 Composite key: defines a unique preference group (e.g., medication/group)
class PreferenceKey {
  final ItemType type;
  final ItemPreferenceField field;

  const PreferenceKey(this.type, this.field);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreferenceKey &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          field == other.field;

  @override
  int get hashCode => type.hashCode ^ field.hashCode;
}

/// 🌱 Controller provider — controller builds its service lazily
final itemPreferenceControllerProvider =
    StateNotifierProvider.family<
      ItemPreferenceController,
      AsyncValue<List<String>>,
      PreferenceKey
    >((ref, key) => ItemPreferenceController(ref: ref, key: key));

/// 🎛️ Controller that handles fetching, adding, removing values
class ItemPreferenceController extends StateNotifier<AsyncValue<List<String>>> {
  final Ref ref;
  final PreferenceKey key;

  ItemPreferenceController({required this.ref, required this.key})
    : super(const AsyncValue.loading()) {
    _load();
  }

  // Lazily construct service (await AfyaKit client + tenant routes)
  late final Future<ItemPreferenceService> _svc = _makeService();

  Future<ItemPreferenceService> _makeService() async {
    final tenantId = ref.read(tenantSlugProvider);
    final client = await ref.read(afyakitClientProvider.future);
    // Ensure ItemPreferenceService has ctor: {required AfyaKitRoutes routes, required Dio dio}
    return ItemPreferenceService(
      routes: AfyaKitRoutes(tenantId),
      dio: client.dio,
    );
  }

  /// 📥 Fetch current list of preferences
  Future<void> _load() async {
    try {
      final svc = await _svc;
      final values = await svc.fetchValues(key.type, key.field);
      state = AsyncValue.data(values);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// ➕ Add new value (if valid and not a duplicate)
  Future<void> add(String value) async {
    final trimmed = value.trim();
    final current = state.value ?? [];

    if (trimmed.isEmpty || current.contains(trimmed)) return;

    // optimistic update
    state = AsyncValue.data([...current, trimmed]);

    try {
      final svc = await _svc;
      await svc.addValue(key.type, key.field, trimmed);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// ➖ Remove a value from the preference list
  Future<void> remove(String value) async {
    final current = state.value ?? [];

    // optimistic update
    state = AsyncValue.data([...current]..remove(value));

    try {
      final svc = await _svc;
      await svc.removeValue(key.type, key.field, value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 🔁 Reload preference values from the backend
  Future<void> reload() => _load();
}
