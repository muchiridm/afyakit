import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/item_preferences/utils/item_preference_field.dart';
import 'package:afyakit/core/import/preferences_matcher/models/field_match_model.dart';
import 'package:afyakit/core/import/preferences_matcher/models/prefs_match_model.dart';
import 'package:afyakit/core/item_preferences/providers/item_preferences_providers.dart';
import 'preferences_matcher_service.dart';

/// Controller provider: builds its own model asynchronously.
/// Screen passes (type, incoming) and just renders the state.
final preferencesMatcherControllerProvider = StateNotifierProvider.autoDispose
    .family<
      PreferencesMatcherController,
      PreferencesMatcherState,
      ({ItemType type, Map<ItemPreferenceField, Iterable<String>> incoming})
    >((ref, args) {
      final svc = ref.watch(preferencesMatcherServiceProvider);
      return PreferencesMatcherController(
        type: args.type,
        incomingByField: args.incoming,
        service: svc,
      );
    });

class PreferencesMatcherState {
  const PreferencesMatcherState({required this.model, this.isBusy = false});

  /// Async model (loading/error/data)
  final AsyncValue<PrefsMatchModel> model;
  final bool isBusy;

  /// Convenience: complete only when data is ready and all selections are filled.
  bool get isComplete =>
      model.maybeWhen(data: (m) => m.isComplete, orElse: () => false);

  PreferencesMatcherState copyWith({
    AsyncValue<PrefsMatchModel>? model,
    bool? isBusy,
  }) => PreferencesMatcherState(
    model: model ?? this.model,
    isBusy: isBusy ?? this.isBusy,
  );
}

class PreferencesMatcherController
    extends StateNotifier<PreferencesMatcherState> {
  PreferencesMatcherController({
    required this.type,
    required this.incomingByField,
    required PreferencesMatcherService service,
  }) : _svc = service,
       super(const PreferencesMatcherState(model: AsyncValue.loading())) {
    _init();
  }

  final ItemType type;
  final Map<ItemPreferenceField, Iterable<String>> incomingByField;
  final PreferencesMatcherService _svc;

  // Expose which fields should be displayed (keeps the screen dumb)
  List<ItemPreferenceField> get fields => fieldsFor(type);

  // ---- lifecycle -------------------------------------------------------------

  Future<void> _init() async {
    try {
      final model = await _svc.build(type, incomingByField);
      state = state.copyWith(model: AsyncValue.data(model));
    } catch (e, st) {
      state = state.copyWith(model: AsyncValue.error(e, st));
    }
  }

  // ---- safe accessors for the view ------------------------------------------

  /// Returns the FieldMatchModel for a given field or null if not ready.
  FieldMatchModel? fieldModel(ItemPreferenceField field) =>
      state.model.maybeWhen(data: (m) => m.byField[field], orElse: () => null);

  // ---- interactions ----------------------------------------------------------

  void select({
    required ItemPreferenceField field,
    required String incoming,
    required String canonical,
  }) {
    final current = state.model;
    if (!current.hasValue) return;
    final m = current.value!;
    final fm = m.byField[field]!;
    final nextSel = Map<String, String>.from(fm.selections)
      ..[incoming] = canonical;

    final nextField = FieldMatchModel(
      field: field,
      incoming: fm.incoming,
      existing: fm.existing,
      selections: nextSel,
    );

    final nextMap = Map<ItemPreferenceField, FieldMatchModel>.from(m.byField)
      ..[field] = nextField;

    state = state.copyWith(
      model: AsyncValue.data(PrefsMatchModel(type, nextMap)),
    );
  }

  Future<void> createAndSelect({
    required ItemPreferenceField field,
    required String incoming,
    required String newValue,
  }) async {
    final current = state.model;
    if (!current.hasValue) return;

    state = state.copyWith(isBusy: true);
    try {
      final updatedExisting = await _svc.createPreferenceValue(
        type: type,
        field: field,
        value: newValue,
      );

      final m = current.value!;
      final fm = m.byField[field]!;
      final nextField = FieldMatchModel(
        field: field,
        incoming: fm.incoming,
        existing: updatedExisting,
        selections: {...fm.selections, incoming: newValue},
      );

      final nextMap = Map<ItemPreferenceField, FieldMatchModel>.from(m.byField)
        ..[field] = nextField;

      state = state.copyWith(
        isBusy: false,
        model: AsyncValue.data(PrefsMatchModel(type, nextMap)),
      );
    } catch (e, st) {
      state = state.copyWith(isBusy: false, model: AsyncValue.error(e, st));
    }
  }

  /// Output a compact mapping: fieldKey -> { incoming -> canonical }
  Map<String, Map<String, String>> buildResult() {
    final current = state.model;
    if (!current.hasValue) return const {};
    final out = <String, Map<String, String>>{};
    current.value!.byField.forEach((field, fm) {
      out[field.key] = Map<String, String>.from(fm.selections);
    });
    return out;
  }
}

/// DI for the service
final preferencesMatcherServiceProvider = Provider<PreferencesMatcherService>((
  ref,
) {
  final prefsSvc = ref.watch(itemPreferenceServiceProvider);
  return PreferencesMatcherService(prefsSvc);
});
