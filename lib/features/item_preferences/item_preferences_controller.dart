import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/item_preferences/utils/item_preference_field.dart';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/features/item_preferences/item_preferences_service.dart';
import 'package:afyakit/shared/providers/api_route_provider.dart';

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

/// 🌱 Provider for managing item preferences for a specific field
final itemPreferenceControllerProvider =
    StateNotifierProvider.family<
      ItemPreferenceController,
      AsyncValue<List<String>>,
      PreferenceKey
    >((ref, key) {
      final apiRoutes = ref.watch(apiRouteProvider);
      final token = ref.watch(tokenProvider); // ✅ add this
      final service = ItemPreferenceService(apiRoutes, token); // ✅ inject both
      return ItemPreferenceController(key: key, api: service);
    });

/// 🎛️ Controller that handles fetching, adding, removing values
class ItemPreferenceController extends StateNotifier<AsyncValue<List<String>>> {
  final PreferenceKey key;
  final ItemPreferenceService api;

  ItemPreferenceController({required this.key, required this.api})
    : super(const AsyncValue.loading()) {
    _load();
  }

  /// 📥 Fetch current list of preferences
  Future<void> _load() async {
    try {
      final values = await api.fetchValues(key.type, key.field);
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

    state = AsyncValue.data([...current, trimmed]);

    try {
      await api.addValue(key.type, key.field, trimmed);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// ➖ Remove a value from the preference list
  Future<void> remove(String value) async {
    final current = state.value ?? [];

    state = AsyncValue.data([...current]..remove(value));

    try {
      await api.removeValue(key.type, key.field, value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 🔁 Reload preference values from the backend
  Future<void> reload() => _load();
}
