// lib/features/clinical/patients/patient_profiles_controller.dart

import 'package:afyakit/features/clinical/patients/patient_profile.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class PatientProfilesState {
  const PatientProfilesState({
    this.items = const <PatientProfile>[],
    this.linkRequests = const <PatientLinkRequest>[],
    this.isLoading = false,
    this.isLoadingLinkRequests = false,
    this.isSaving = false,
    this.error,
    this.search = '',
    this.contactId,
    this.relationship,
    this.isActive,
    this.linkRequestStatus,
  });

  final List<PatientProfile> items;
  final List<PatientLinkRequest> linkRequests;

  final bool isLoading;
  final bool isLoadingLinkRequests;
  final bool isSaving;
  final String? error;

  final String search;
  final String? contactId;
  final ContactPatientRelationship? relationship;
  final bool? isActive;

  final PatientLinkRequestStatus? linkRequestStatus;

  bool get hasFilters {
    return search.trim().isNotEmpty ||
        contactId != null ||
        relationship != null ||
        isActive != null;
  }

  bool get hasPendingLinkRequests {
    return linkRequests.any((request) => request.isPending);
  }

  PatientProfilesState copyWith({
    List<PatientProfile>? items,
    List<PatientLinkRequest>? linkRequests,
    bool? isLoading,
    bool? isLoadingLinkRequests,
    bool? isSaving,
    String? error,
    bool clearError = false,
    String? search,
    String? contactId,
    ContactPatientRelationship? relationship,
    bool? isActive,
    PatientLinkRequestStatus? linkRequestStatus,
    bool clearContactId = false,
    bool clearRelationship = false,
    bool clearIsActive = false,
    bool clearLinkRequestStatus = false,
  }) {
    return PatientProfilesState(
      items: items ?? this.items,
      linkRequests: linkRequests ?? this.linkRequests,
      isLoading: isLoading ?? this.isLoading,
      isLoadingLinkRequests:
          isLoadingLinkRequests ?? this.isLoadingLinkRequests,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      search: search ?? this.search,
      contactId: clearContactId ? null : (contactId ?? this.contactId),
      relationship: clearRelationship
          ? null
          : (relationship ?? this.relationship),
      isActive: clearIsActive ? null : (isActive ?? this.isActive),
      linkRequestStatus: clearLinkRequestStatus
          ? null
          : (linkRequestStatus ?? this.linkRequestStatus),
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

  // ─────────────────────────────────────────────
  // Patient profiles
  // ─────────────────────────────────────────────

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final items = await _service.list(
        search: _nullable(state.search),
        contactId: state.contactId,
        relationship: state.relationship,
        isActive: state.isActive,
      );

      state = state.copyWith(
        items: _sortedPatients(items),
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load patient profiles: $e',
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> refreshAll() async {
    await load();
    await loadLinkRequests();
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
  }

  void setContactId(String? value) {
    final trimmed = _nullable(value);

    state = state.copyWith(contactId: trimmed, clearContactId: trimmed == null);
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
    final trimmedContactId = _nullable(contactId);

    state = state.copyWith(
      search: search ?? state.search,
      contactId: resetContactId
          ? null
          : contactId == null
          ? state.contactId
          : trimmedContactId,
      relationship: resetRelationship
          ? null
          : (relationship ?? state.relationship),
      isActive: resetIsActive ? null : (isActive ?? state.isActive),
      clearContactId:
          resetContactId || (contactId != null && trimmedContactId == null),
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

  Future<PatientProfile> create(PatientProfileUpsertInput input) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final created = await _service.create(input);
      final items = _upsertPatient(state.items, created);

      state = state.copyWith(items: items, isSaving: false, clearError: true);

      return created;
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
      final items = _upsertPatient(state.items, linked);

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

  Future<PatientProfile> update(
    String patientId,
    PatientProfileUpsertInput input,
  ) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final updated = await _service.update(patientId, input);
      final items = _upsertPatient(state.items, updated);

      state = state.copyWith(items: items, isSaving: false, clearError: true);

      return updated;
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
      await _service.remove(patientId);

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

  // ─────────────────────────────────────────────
  // Patient link requests
  // ─────────────────────────────────────────────

  Future<void> loadLinkRequests({
    PatientLinkRequestStatus? status,
    String? patientId,
    bool resetStatus = false,
  }) async {
    state = state.copyWith(
      isLoadingLinkRequests: true,
      linkRequestStatus: resetStatus ? null : status,
      clearLinkRequestStatus: resetStatus,
      clearError: true,
    );

    try {
      final requests = await _service.listLinkRequests(
        status: resetStatus ? null : (status ?? state.linkRequestStatus),
        patientId: _nullable(patientId),
      );

      state = state.copyWith(
        linkRequests: _sortedLinkRequests(requests),
        isLoadingLinkRequests: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingLinkRequests: false,
        error: 'Failed to load patient link requests: $e',
      );
    }
  }

  Future<PatientLinkRequest> createLinkRequest(
    String patientId,
    PatientLinkRequestCreateInput input,
  ) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final created = await _service.createLinkRequest(patientId, input);
      final requests = _upsertLinkRequest(state.linkRequests, created);

      state = state.copyWith(
        linkRequests: requests,
        isSaving: false,
        clearError: true,
      );

      return created;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to submit link request: $e',
      );
      rethrow;
    }
  }

  Future<PatientLinkRequest> requestPayerLink(
    String patientId,
    PatientLinkRequestCreateInput input,
  ) {
    return createLinkRequest(patientId, input);
  }

  Future<PatientLinkRequest> approveLinkRequest(
    String requestId,
    PatientLinkRequestApproveInput input,
  ) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final approved = await _service.approveLinkRequest(requestId, input);
      final requests = _upsertLinkRequest(state.linkRequests, approved);

      state = state.copyWith(
        linkRequests: requests,
        isSaving: false,
        clearError: true,
      );

      await load();

      return approved;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to approve link request: $e',
      );
      rethrow;
    }
  }

  Future<PatientLinkRequest> rejectLinkRequest(
    String requestId,
    PatientLinkRequestRejectInput input,
  ) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final rejected = await _service.rejectLinkRequest(requestId, input);
      final requests = _upsertLinkRequest(state.linkRequests, rejected);

      state = state.copyWith(
        linkRequests: requests,
        isSaving: false,
        clearError: true,
      );

      return rejected;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to reject link request: $e',
      );
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Sorting / local state helpers
  // ─────────────────────────────────────────────

  static List<PatientProfile> _upsertPatient(
    List<PatientProfile> current,
    PatientProfile patient,
  ) {
    final exists = current.any((p) => p.patientId == patient.patientId);

    final items = exists
        ? current
              .map((p) => p.patientId == patient.patientId ? patient : p)
              .toList(growable: false)
        : <PatientProfile>[patient, ...current];

    return _sortedPatients(items);
  }

  static List<PatientLinkRequest> _upsertLinkRequest(
    List<PatientLinkRequest> current,
    PatientLinkRequest request,
  ) {
    final exists = current.any((r) => r.requestId == request.requestId);

    final items = exists
        ? current
              .map((r) => r.requestId == request.requestId ? request : r)
              .toList(growable: false)
        : <PatientLinkRequest>[request, ...current];

    return _sortedLinkRequests(items);
  }

  static List<PatientProfile> _sortedPatients(List<PatientProfile> items) {
    final sorted = [...items];

    sorted.sort((a, b) {
      final byName = a.fullName.toLowerCase().compareTo(
        b.fullName.toLowerCase(),
      );

      if (byName != 0) return byName;

      return a.patientId.compareTo(b.patientId);
    });

    return sorted;
  }

  static List<PatientLinkRequest> _sortedLinkRequests(
    List<PatientLinkRequest> items,
  ) {
    final sorted = [...items];

    sorted.sort((a, b) {
      final aCreated = a.createdAt;
      final bCreated = b.createdAt;

      if (aCreated != null && bCreated != null) {
        return bCreated.compareTo(aCreated);
      }

      if (aCreated != null) return -1;
      if (bCreated != null) return 1;

      return b.requestId.compareTo(a.requestId);
    });

    return sorted;
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
