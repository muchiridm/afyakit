// lib/features/clinical/patients/patient_profiles_controller.dart

import 'package:afyakit/features/clinical/patients/patient_profile.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_service.dart';
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
    this.contactId,
    this.relationship,
    this.isActive,
  });

  final List<PatientProfile> items;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  final String search;
  final String? contactId;
  final ContactPatientRelationship? relationship;
  final bool? isActive;

  PatientProfilesState copyWith({
    List<PatientProfile>? items,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
    String? search,
    String? contactId,
    ContactPatientRelationship? relationship,
    bool? isActive,
    bool clearContactId = false,
    bool clearRelationship = false,
    bool clearIsActive = false,
  }) {
    return PatientProfilesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      search: search ?? this.search,
      contactId: clearContactId ? null : (contactId ?? this.contactId),
      relationship: clearRelationship
          ? null
          : (relationship ?? this.relationship),
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
        contactId: state.contactId,
        relationship: state.relationship,
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

  void setContactId(String? value) {
    final trimmed = value?.trim();
    final empty = trimmed == null || trimmed.isEmpty;

    state = state.copyWith(
      contactId: empty ? null : trimmed,
      clearContactId: empty,
    );
  }

  void setRelationship(ContactPatientRelationship? value) {
    state = state.copyWith(
      relationship: value,
      clearRelationship: value == null,
    );
  }

  void setIsActive(bool? value) {
    state = state.copyWith(isActive: value, clearIsActive: value == null);
  }

  Future<void> applyFilters({
    String? search,
    String? contactId,
    ContactPatientRelationship? relationship,
    bool? isActive,
    bool resetContactId = false,
    bool resetRelationship = false,
    bool resetIsActive = false,
  }) async {
    final trimmedContactId = contactId?.trim();

    state = state.copyWith(
      search: search ?? state.search,
      contactId: resetContactId
          ? null
          : ((trimmedContactId == null || trimmedContactId.isEmpty)
                ? state.contactId
                : trimmedContactId),
      relationship: resetRelationship
          ? null
          : (relationship ?? state.relationship),
      isActive: resetIsActive ? null : (isActive ?? state.isActive),
      clearContactId:
          resetContactId || (contactId != null && trimmedContactId!.isEmpty),
      clearRelationship: resetRelationship,
      clearIsActive: resetIsActive,
    );

    await load();
  }

  Future<void> clearFilters() async {
    state = state.copyWith(
      search: '',
      clearContactId: true,
      clearRelationship: true,
      clearIsActive: true,
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

  Future<PatientProfile> linkToSelf(
    String patientId,
    PatientProfileLinkToSelfInput input,
  ) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final linked = await _service.linkToSelf(patientId, input);

      final existingIndex = state.items.indexWhere(
        (p) => p.patientId == patientId,
      );

      List<PatientProfile> items;
      if (existingIndex >= 0) {
        items = state.items
            .map((p) => p.patientId == patientId ? linked : p)
            .toList(growable: false);
      } else {
        items = <PatientProfile>[linked, ...state.items];
      }

      items.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

      state = state.copyWith(items: items, isSaving: false, clearError: true);

      return linked;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to link patient profile: $e',
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
