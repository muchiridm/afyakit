// lib/features/clinical/profiles/controllers/profiles_controller.dart

import 'package:afyakit/features/clinical/profiles/models/profile_link_request_models.dart';
import 'package:afyakit/features/clinical/profiles/models/profile_models.dart';
import 'package:afyakit/features/clinical/profiles/services/profiles_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ProfilesScope {
  const ProfilesScope({this.contactId, this.allowExplicitContactLink = false});

  final String? contactId;
  final bool allowExplicitContactLink;

  String? get cleanContactId => ProfilesController.nullable(contactId);

  bool get isContactScoped => cleanContactId != null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProfilesScope &&
            other.cleanContactId == cleanContactId &&
            other.allowExplicitContactLink == allowExplicitContactLink;
  }

  @override
  int get hashCode => Object.hash(cleanContactId, allowExplicitContactLink);
}

@immutable
class ProfilesState {
  const ProfilesState({
    this.items = const <Profile>[],
    this.linkRequests = const <ProfileLinkRequest>[],
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

  final List<Profile> items;
  final List<ProfileLinkRequest> linkRequests;

  final bool isLoading;
  final bool isLoadingLinkRequests;
  final bool isSaving;
  final String? error;

  final String search;
  final String? contactId;
  final ProfileContactRelationship? relationship;
  final bool? isActive;

  final ProfileLinkRequestStatus? linkRequestStatus;

  bool get hasFilters {
    return search.trim().isNotEmpty ||
        contactId != null ||
        relationship != null ||
        isActive != null;
  }

  bool get hasPendingLinkRequests {
    return linkRequests.any((request) => request.isPending);
  }

  ProfilesState copyWith({
    List<Profile>? items,
    List<ProfileLinkRequest>? linkRequests,
    bool? isLoading,
    bool? isLoadingLinkRequests,
    bool? isSaving,
    String? error,
    bool clearError = false,
    String? search,
    String? contactId,
    ProfileContactRelationship? relationship,
    bool? isActive,
    ProfileLinkRequestStatus? linkRequestStatus,
    bool clearContactId = false,
    bool clearRelationship = false,
    bool clearIsActive = false,
    bool clearLinkRequestStatus = false,
  }) {
    return ProfilesState(
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

final profilesControllerProvider = StateNotifierProvider.autoDispose
    .family<ProfilesController, ProfilesState, ProfilesScope>((ref, scope) {
      return ProfilesController(
        () => ref.read(profilesServiceProvider),
        fixedContactId: scope.cleanContactId,
      );
    });

class ProfilesController extends StateNotifier<ProfilesState> {
  ProfilesController(this._readService, {String? fixedContactId})
    : _fixedContactId = nullable(fixedContactId),
      super(ProfilesState(contactId: nullable(fixedContactId)));

  final ProfilesService Function() _readService;
  final String? _fixedContactId;

  ProfilesService get _service => _readService();

  bool get isContactScoped => _fixedContactId != null;

  // ─────────────────────────────────────────────
  // Profiles
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
        items: _sortedProfiles(items),
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load profiles: $e',
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

  void setRelationship(ProfileContactRelationship? value) {
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
    ProfileContactRelationship? relationship,
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

  Future<Profile> create(ProfileUpsertInput input) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final effectiveInput = _withFixedContact(input);
      final created = await _service.create(effectiveInput);
      final items = _upsertProfile(state.items, created);

      state = state.copyWith(items: items, isSaving: false, clearError: true);

      return created;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to create profile: $e',
      );
      rethrow;
    }
  }

  Future<Profile> linkToSelf(
    String patientId,
    ProfileLinkToSelfInput input,
  ) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final linked = await _service.linkToSelf(patientId, input);
      final items = _upsertProfile(state.items, linked);

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

  Future<Profile> update(String patientId, ProfileUpsertInput input) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final effectiveInput = _withFixedContact(input);
      final updated = await _service.update(patientId, effectiveInput);
      final items = _upsertProfile(state.items, updated);

      state = state.copyWith(items: items, isSaving: false, clearError: true);

      return updated;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to update profile: $e',
      );
      rethrow;
    }
  }

  Future<void> remove(String patientId) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _service.remove(patientId);

      final items = state.items
          .where((p) => p.profileId != patientId)
          .toList(growable: false);

      state = state.copyWith(items: items, isSaving: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to delete profile: $e',
      );
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Staff direct profile-contact links
  // ─────────────────────────────────────────────

  Future<Profile> linkContactToProfile({
    required String profileId,
    required ProfileContactLinkInput input,
  }) async {
    if (isContactScoped) {
      throw StateError('Scoped members cannot link arbitrary contacts.');
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final linked = await _service.linkContact(profileId, input);

      final items = _upsertProfile(state.items, linked);

      state = state.copyWith(items: items, isSaving: false, clearError: true);

      return linked;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to link contact to profile: $e',
      );

      rethrow;
    }
  }

  Future<Profile> delinkContact({
    required String profileId,
    required String contactId,
  }) async {
    if (isContactScoped) {
      throw StateError('Scoped member views cannot delink arbitrary contacts.');
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final updated = await _service.delinkContact(
        profileId: profileId,
        contactId: contactId,
      );

      final items = _upsertProfile(state.items, updated);

      state = state.copyWith(items: items, isSaving: false, clearError: true);

      return updated;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to delink contact from profile: $e',
      );

      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Profile link requests
  // ─────────────────────────────────────────────

  Future<void> loadLinkRequests({
    ProfileLinkRequestStatus? status,
    String? profileId,
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
        profileId: nullable(profileId),
      );

      state = state.copyWith(
        linkRequests: _sortedLinkRequests(requests),
        isLoadingLinkRequests: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingLinkRequests: false,
        error: 'Failed to load profile link requests: $e',
      );
    }
  }

  Future<ProfileLinkRequest> createLinkRequest(
    String profileId,
    ProfileLinkRequestCreateInput input,
  ) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final created = await _service.createLinkRequest(profileId, input);
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

  Future<ProfileLinkRequest> requestPayerLink(
    String profileId,
    ProfileLinkRequestCreateInput input,
  ) {
    return createLinkRequest(profileId, input);
  }

  Future<ProfileLinkRequest> approveLinkRequest(
    String requestId,
    ProfileLinkRequestApproveInput input,
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

  Future<ProfileLinkRequest> approvePayerLinkRequest(
    ProfileLinkRequest request, {
    String? contactId,
    String? accountNumber,
    String? contactDisplayName,
    ProfileContactRelationship? relationship,
  }) {
    final resolvedContactId = nullable(contactId) ?? request.targetContactId;
    final resolvedAccountNumber =
        nullable(accountNumber) ?? request.targetAccountNumber;
    final resolvedDisplayName =
        nullable(contactDisplayName) ?? request.targetContactDisplayName;

    return approveLinkRequest(
      request.requestId,
      ProfileLinkRequestApproveInput(
        contactId: nullable(resolvedContactId),
        accountNumber: nullable(resolvedContactId) == null
            ? nullable(resolvedAccountNumber)
            : null,
        contactDisplayName: nullable(resolvedDisplayName),
        relationship: relationship ?? request.relationship,
      ),
    );
  }

  Future<ProfileLinkRequest> rejectLinkRequest(
    String requestId,
    ProfileLinkRequestRejectInput input,
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

  ProfileUpsertInput _withFixedContact(ProfileUpsertInput input) {
    if (_fixedContactId == null) return input;

    return ProfileUpsertInput(
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

  static List<Profile> _upsertProfile(List<Profile> current, Profile profile) {
    final exists = current.any((item) => item.profileId == profile.profileId);

    final items = exists
        ? current
              .map(
                (item) => item.profileId == profile.profileId ? profile : item,
              )
              .toList(growable: false)
        : <Profile>[profile, ...current];

    return _sortedProfiles(items);
  }

  static List<ProfileLinkRequest> _upsertLinkRequest(
    List<ProfileLinkRequest> current,
    ProfileLinkRequest request,
  ) {
    final exists = current.any((r) => r.requestId == request.requestId);

    final items = exists
        ? current
              .map((r) => r.requestId == request.requestId ? request : r)
              .toList(growable: false)
        : <ProfileLinkRequest>[request, ...current];

    return _sortedLinkRequests(items);
  }

  static List<Profile> _sortedProfiles(List<Profile> items) {
    final sorted = [...items];

    sorted.sort((a, b) {
      final byName = a.fullName.toLowerCase().compareTo(
        b.fullName.toLowerCase(),
      );

      if (byName != 0) return byName;

      return a.profileId.compareTo(b.profileId);
    });

    return sorted;
  }

  static List<ProfileLinkRequest> _sortedLinkRequests(
    List<ProfileLinkRequest> items,
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
