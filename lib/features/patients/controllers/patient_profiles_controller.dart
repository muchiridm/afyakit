// lib/features/patients/controllers/patient_profiles_controller.dart

import 'package:afyakit/features/patients/models/patient_profile.dart';
import 'package:afyakit/features/patients/services/patient_profiles_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class PatientProfilesState {
  const PatientProfilesState({
    this.items = const <PatientProfile>[],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.search = '',
    this.insurance,
    this.scheme,
    this.isActive,
  });

  final List<PatientProfile> items;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  final String search;
  final String? insurance;
  final String? scheme;
  final bool? isActive;

  PatientProfilesState copyWith({
    List<PatientProfile>? items,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
    String? search,
    String? insurance,
    String? scheme,
    bool? isActive,
    bool clearInsurance = false,
    bool clearScheme = false,
    bool clearIsActive = false,
  }) {
    return PatientProfilesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      search: search ?? this.search,
      insurance: clearInsurance ? null : (insurance ?? this.insurance),
      scheme: clearScheme ? null : (scheme ?? this.scheme),
      isActive: clearIsActive ? null : (isActive ?? this.isActive),
    );
  }
}

final patientProfilesControllerProvider =
    StateNotifierProvider.autoDispose<
      PatientProfilesController,
      PatientProfilesState
    >((ref) {
      final service = ref.watch(patientProfilesServiceProvider);
      return PatientProfilesController(service)..load();
    });

class PatientProfilesController extends StateNotifier<PatientProfilesState> {
  PatientProfilesController(this._service)
    : super(const PatientProfilesState());

  final PatientProfilesService _service;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final items = await _service.list(
        search: state.search.trim().isEmpty ? null : state.search.trim(),
        insurance: state.insurance,
        scheme: state.scheme,
        isActive: state.isActive,
      );

      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load patient profiles: $e',
      );
    }
  }

  Future<void> refresh() => load();

  void setSearch(String value) {
    state = state.copyWith(search: value);
  }

  void setInsurance(String? value) {
    final trimmed = value?.trim();
    state = state.copyWith(
      insurance: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      clearInsurance: trimmed == null || trimmed.isEmpty,
    );
  }

  void setScheme(String? value) {
    final trimmed = value?.trim();
    state = state.copyWith(
      scheme: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      clearScheme: trimmed == null || trimmed.isEmpty,
    );
  }

  void setIsActive(bool? value) {
    state = state.copyWith(isActive: value, clearIsActive: value == null);
  }

  Future<void> applyFilters({
    String? search,
    String? insurance,
    String? scheme,
    bool? isActive,
    bool resetIsActive = false,
  }) async {
    state = state.copyWith(
      search: search ?? state.search,
      insurance: insurance?.trim().isEmpty == true ? null : insurance,
      scheme: scheme?.trim().isEmpty == true ? null : scheme,
      isActive: resetIsActive ? null : (isActive ?? state.isActive),
      clearInsurance: insurance != null && insurance.trim().isEmpty,
      clearScheme: scheme != null && scheme.trim().isEmpty,
      clearIsActive: resetIsActive,
    );

    await load();
  }

  Future<void> create(PatientProfileUpsertInput input) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final created = await _service.create(input);
      final items = <PatientProfile>[created, ...state.items]
        ..sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );

      state = state.copyWith(items: items, isSaving: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to create patient profile: $e',
      );
      rethrow;
    }
  }

  Future<void> update(String patientId, PatientProfileUpsertInput input) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final updated = await _service.update(patientId, input);
      final items =
          state.items
              .map((p) => p.patientId == patientId ? updated : p)
              .toList(growable: false)
            ..sort(
              (a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );

      state = state.copyWith(items: items, isSaving: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to update patient profile: $e',
      );
      rethrow;
    }
  }

  Future<void> remove(String patientId) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _service.delete(patientId);

      final items = state.items
          .where((p) => p.patientId != patientId)
          .toList(growable: false);

      state = state.copyWith(items: items, isSaving: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to delete patient profile: $e',
      );
      rethrow;
    }
  }
}
