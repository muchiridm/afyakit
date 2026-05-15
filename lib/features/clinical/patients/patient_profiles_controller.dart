import 'package:afyakit/features/clinical/patients/models/patient_link_request_models.dart';
import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class PatientProfilesScope {
  const PatientProfilesScope({
    this.contactId,
    this.allowExplicitContactLink = false,
  });

  final String? contactId;
  final bool allowExplicitContactLink;

  String? get cleanContactId => PatientProfilesController.nullable(contactId);

  bool get isContactScoped => cleanContactId != null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PatientProfilesScope &&
            other.cleanContactId == cleanContactId &&
            other.allowExplicitContactLink == allowExplicitContactLink;
  }

  @override
  int get hashCode => Object.hash(cleanContactId, allowExplicitContactLink);
}

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
  final PatientContactRelationship? relationship;
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
    PatientContactRelationship? relationship,
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

final patientProfilesControllerProvider = StateNotifierProvider.autoDispose
    .family<
      PatientProfilesController,
      PatientProfilesState,
      PatientProfilesScope
    >((ref, scope) {
      return PatientProfilesController(
        () => ref.read(patientProfilesServiceProvider),
        fixedContactId: scope.cleanContactId,
      );
    });

class PatientProfilesController extends StateNotifier<PatientProfilesState> {
  PatientProfilesController(this._readService, {String? fixedContactId})
    : _fixedContactId = nullable(fixedContactId),
      super(PatientProfilesState(contactId: nullable(fixedContactId)));

  final PatientProfilesService Function() _readService;
  final String? _fixedContactId;

  PatientProfilesService get _service => _readService();

  bool get isContactScoped => _fixedContactId != null;

  // ─────────────────────────────────────────────
  // Patient profiles
  // ─────────────────────────────────────────────

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final items = await _service.list(
        search: nullable(state.search),
        contactId: _fixedContactId ?? state.contactId,
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
    if (isContactScoped) return;

    final trimmed = nullable(value);

    state = state.copyWith(contactId: trimmed, clearContactId: trimmed == null);
  }

  void setRelationship(PatientContactRelationship? value) {
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
    PatientContactRelationship? relationship,
    bool? isActive,
    bool resetContactId = false,
    bool resetRelationship = false,
    bool resetIsActive = false,
  }) async {
    final trimmedContactId = nullable(contactId);

    state = state.copyWith(
      search: search ?? state.search,
      contactId: isContactScoped
          ? _fixedContactId
          : resetContactId
          ? null
          : contactId == null
          ? state.contactId
          : trimmedContactId,
      relationship: resetRelationship
          ? null
          : (relationship ?? state.relationship),
      isActive: resetIsActive ? null : (isActive ?? state.isActive),
      clearContactId: isContactScoped
          ? false
          : resetContactId || (contactId != null && trimmedContactId == null),
      clearRelationship: resetRelationship,
      clearIsActive: resetIsActive,
    );

    await load();
  }

  Future<void> clearFilters() async {
    state = state.copyWith(
      search: '',
      contactId: _fixedContactId,
      clearContactId: _fixedContactId == null,
      clearRelationship: true,
      clearIsActive: true,
    );

    await load();
  }

  Future<PatientProfile> create(PatientProfileUpsertInput input) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final effectiveInput = _withFixedContact(input);
      final created = await _service.create(effectiveInput);
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
      final effectiveInput = _withFixedContact(input);
      final updated = await _service.update(patientId, effectiveInput);
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
  // Staff direct patient-contact links
  // ─────────────────────────────────────────────

  Future<PatientProfile> linkContactToPatient({
    required String patientId,
    required PatientContactLinkInput input,
  }) async {
    if (isContactScoped) {
      throw StateError('Scoped member views cannot link arbitrary contacts.');
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final linked = await _service.linkContactToPatient(
        patientId: patientId,
        input: input,
      );

      final items = _upsertPatient(state.items, linked);

      state = state.copyWith(items: items, isSaving: false, clearError: true);

      return linked;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to link contact to patient: $e',
      );
      rethrow;
    }
  }

  Future<PatientProfile> delinkContactFromPatient({
    required String patientId,
    required String contactId,
  }) async {
    if (isContactScoped) {
      throw StateError('Scoped member views cannot delink arbitrary contacts.');
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final updated = await _service.delinkContactFromPatient(
        patientId: patientId,
        contactId: contactId,
      );

      final items = _upsertPatient(state.items, updated);

      state = state.copyWith(items: items, isSaving: false, clearError: true);

      return updated;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to delink contact from patient: $e',
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
    final effectiveStatus = resetStatus
        ? null
        : (status ?? state.linkRequestStatus);

    state = state.copyWith(
      isLoadingLinkRequests: true,
      linkRequestStatus: effectiveStatus,
      clearLinkRequestStatus: resetStatus,
      clearError: true,
    );

    try {
      final requests = await _service.listLinkRequests(
        status: effectiveStatus,
        patientId: nullable(patientId),
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
    if (isContactScoped) {
      throw StateError('Scoped member views cannot approve link requests.');
    }

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

  Future<PatientLinkRequest> approvePayerLinkRequest(
    PatientLinkRequest request, {
    String? contactId,
    String? accountNumber,
    String? contactDisplayName,
    PatientContactRelationship? relationship,
  }) {
    final resolvedContactId = nullable(contactId) ?? request.targetContactId;
    final resolvedAccountNumber =
        nullable(accountNumber) ?? request.targetAccountNumber;
    final resolvedDisplayName =
        nullable(contactDisplayName) ?? request.targetContactDisplayName;

    return approveLinkRequest(
      request.requestId,
      PatientLinkRequestApproveInput(
        contactId: nullable(resolvedContactId),
        accountNumber: nullable(resolvedContactId) == null
            ? nullable(resolvedAccountNumber)
            : null,
        contactDisplayName: nullable(resolvedDisplayName),
        relationship: relationship ?? request.relationship,
      ),
    );
  }

  Future<PatientLinkRequest> rejectLinkRequest(
    String requestId,
    PatientLinkRequestRejectInput input,
  ) async {
    if (isContactScoped) {
      throw StateError('Scoped member views cannot reject link requests.');
    }

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
  // Input scope helpers
  // ─────────────────────────────────────────────

  PatientProfileUpsertInput _withFixedContact(PatientProfileUpsertInput input) {
    if (_fixedContactId == null) return input;

    return PatientProfileUpsertInput(
      fullName: input.fullName,
      dob: input.dob,
      gender: input.gender,
      contactId: _fixedContactId,
      relationship: input.relationship,
      phone: input.phone,
      email: input.email,
      nationalId: input.nationalId,
      notes: input.notes,
      isActive: input.isActive,
    );
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

  static String? nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
