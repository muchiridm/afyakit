// lib/core/import/preferences_matcher/providers/preferences_matcher_controller_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

// afyakitClientProvider

import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/item_preferences/utils/item_preference_field.dart';
import 'package:afyakit/core/import/preferences_matcher/models/field_match_model.dart';
import 'package:afyakit/core/import/preferences_matcher/models/prefs_match_model.dart';
import 'package:afyakit/core/item_preferences/providers/item_preferences_providers.dart';
import 'preferences_matcher_service.dart';

/// Controller provider: screen passes (type, incoming), controller does the async wiring.
final preferencesMatcherControllerProvider = StateNotifierProvider.autoDispose
    .family<
      PreferencesMatcherController,
      PreferencesMatcherState,
      ({ItemType type, Map<ItemPreferenceField, Iterable<String>> incoming})
    >(
      (ref, args) => PreferencesMatcherController(
        ref: ref,
        type: args.type,
        incomingByField: args.incoming,
      ),
    );

class PreferencesMatcherState {
  const PreferencesMatcherState({required this.model, this.isBusy = false});

  final AsyncValue<PrefsMatchModel> model;
  final bool isBusy;

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
    required this.ref,
    required this.type,
    required this.incomingByField,
  }) : super(const PreferencesMatcherState(model: AsyncValue.loading())) {
    _init();
  }

  final Ref ref;
  final ItemType type;
  final Map<ItemPreferenceField, Iterable<String>> incomingByField;

  // Lazily construct PreferencesMatcherService by awaiting ItemPreferenceService (which itself awaits AfyaKit client).
  late final Future<PreferencesMatcherService> _svc = _makeService();

  Future<PreferencesMatcherService> _makeService() async {
    // Option A: Reuse your existing service provider (async)
    final prefsSvc = await ref.read(itemPreferenceServiceProvider.future);
    return PreferencesMatcherService(prefsSvc);

    // Option B (direct wiring, if you prefer to bypass the provider):
    // final tenantId = ref.read(tenantIdProvider);
    // final client   = await ref.read(afyakitClientProvider.future);
    // final itemPref = ItemPreferenceService(
    //   routes: AfyaKitRoutes(tenantId),
    //   dio: client.dio,
    // );
    // return PreferencesMatcherService(itemPref);
  }

  // Expose which fields should be displayed (keeps the screen dumb)
  List<ItemPreferenceField> get fields => fieldsFor(type);

  // ---- lifecycle -------------------------------------------------------------
  Future<void> _init() async {
    try {
      final svc = await _svc;
      final model = await svc.build(type, incomingByField);
      state = state.copyWith(model: AsyncValue.data(model));
    } catch (e, st) {
      state = state.copyWith(model: AsyncValue.error(e, st));
    }
  }

  // ---- safe accessors for the view ------------------------------------------
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
      final svc = await _svc;
      final updatedExisting = await svc.createPreferenceValue(
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

  /// Output: fieldKey -> { incoming -> canonical }
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

/// DI for the matcher service (async wrapper, if you want to use it elsewhere)
final preferencesMatcherServiceProvider =
    FutureProvider<PreferencesMatcherService>((ref) async {
      final prefsSvc = await ref.watch(itemPreferenceServiceProvider.future);
      return PreferencesMatcherService(prefsSvc);
    });
