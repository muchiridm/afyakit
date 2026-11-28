// lib/features/records/health_profiles/profiles_controller.dart

import 'package:afyakit/features/records/health_profiles/profile_link_request_models.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/profiles_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ProfilesScope {
  const ProfilesScope({
    this.accountNumber,
    this.memberMode = false,
    this.allowExplicitContactLink = false,
  });

  final String? accountNumber;
  final bool memberMode;
  final bool allowExplicitContactLink;

  String? get cleanAccountNumber => ProfilesController.nullable(accountNumber);

  bool get isContactScoped => memberMode || cleanAccountNumber != null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProfilesScope &&
            other.cleanAccountNumber == cleanAccountNumber &&
            other.memberMode == memberMode &&
            other.allowExplicitContactLink == allowExplicitContactLink;
  }

  @override
  int get hashCode =>
      Object.hash(cleanAccountNumber, memberMode, allowExplicitContactLink);
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
    this.accountNumber,
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
  final String? accountNumber;
  final ProfileContactRelationship? relationship;
  final bool? isActive;

  final ProfileLinkRequestStatus? linkRequestStatus;

  bool get hasFilters {
    return search.trim().isNotEmpty ||
        accountNumber != null ||
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
    String? accountNumber,
    ProfileContactRelationship? relationship,
    bool? isActive,
    ProfileLinkRequestStatus? linkRequestStatus,
    bool clearAccountNumber = false,
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
      accountNumber: clearAccountNumber
          ? null
          : (accountNumber ?? this.accountNumber),
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
      final service = ref.watch(profilesServiceProvider);
      return ProfilesController(
        () => service,
        fixedAccountNumber: scope.cleanAccountNumber,
        memberMode: scope.memberMode,
      );
    });

class ProfilesController extends StateNotifier<ProfilesState> {
  ProfilesController(
    this._readService, {
    String? fixedAccountNumber,
    bool memberMode = false,
  }) : _memberMode = memberMode,
       _fixedAccountNumber = nullable(fixedAccountNumber),
       super(ProfilesState(accountNumber: nullable(fixedAccountNumber)));

  final ProfilesService Function() _readService;
  final String? _fixedAccountNumber;
  final bool _memberMode;

  ProfilesService get _service => _readService();
  @override
  set state(ProfilesState value) {
    if (mounted) super.state = value;
  }

  int _loadRevision = 0;

  bool get isContactScoped => _memberMode || _fixedAccountNumber != null;

  // ─────────────────────────────────────────────
  // Profiles
  // ─────────────────────────────────────────────

  Future<void> load() async {
    final request = ++_loadRevision;
    // Fail closed: missing member identity must never become a directory query.
    if (_memberMode && _fixedAccountNumber == null) {
      state = state.copyWith(
        items: const <Profile>[],
        isLoading: false,
        error:
            'Your Native Contact account is unavailable. Please sign in again.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final items = await _service.list(
        search: nullable(state.search),
        accountNumber: _fixedAccountNumber ?? state.accountNumber,
        relationship: state.relationship,
        isActive: state.isActive,
      );

      if (!mounted || request != _loadRevision) return;
      state = state.copyWith(
        items: _sortedProfiles(items),
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (!mounted || request != _loadRevision) return;
      state = state.copyWith(
        items: const [],
        linkRequests: const [],
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

  void setAccountNumber(String? value) {
    if (isContactScoped) return;

    final trimmed = nullable(value);

    state = state.copyWith(
      accountNumber: trimmed,
      clearAccountNumber: trimmed == null,
    );
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
    String? accountNumber,
    ProfileContactRelationship? relationship,
    bool? isActive,
    bool resetAccountNumber = false,
    bool resetRelationship = false,
    bool resetIsActive = false,
  }) async {
    final trimmedAccountNumber = nullable(accountNumber);

    state = state.copyWith(
      search: search ?? state.search,
      accountNumber: isContactScoped
          ? _fixedAccountNumber
          : resetAccountNumber
          ? null
          : accountNumber == null
          ? state.accountNumber
          : trimmedAccountNumber,
      relationship: resetRelationship
          ? null
          : (relationship ?? state.relationship),
      isActive: resetIsActive ? null : (isActive ?? state.isActive),
      clearAccountNumber: isContactScoped
          ? false
          : resetAccountNumber ||
                (accountNumber != null && trimmedAccountNumber == null),
      clearRelationship: resetRelationship,
      clearIsActive: resetIsActive,
    );

    await load();
  }

  Future<void> clearFilters() async {
    state = state.copyWith(
      search: '',
      accountNumber: _fixedAccountNumber,
      clearAccountNumber: _fixedAccountNumber == null,
      clearRelationship: true,
      clearIsActive: true,
    );

    await load();
  }

  Future<Profile> create(
    ProfileUpsertInput input, {
    Map<String, Object?>? authorization,
  }) async {
    _requireMemberAccount();
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      if (_memberMode &&
          !const <ProfileContactRelationship>{
            ProfileContactRelationship.self,
            ProfileContactRelationship.child,
            ProfileContactRelationship.parent,
            ProfileContactRelationship.guardian,
          }.contains(input.relationship)) {
        throw StateError(
          'Select Self, Child, Parent or Guardian when creating a member profile.',
        );
      }
      final effectiveInput = _withFixedContact(input);
      final created = await _service.create(
        effectiveInput,
        authorization: authorization,
      );
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

  Future<Profile> update(String profileId, ProfileUpsertInput input) async {
    _requireMemberAccount();
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      _withFixedContact(input);
      final updated = await _service.update(profileId, input);
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

  /// Trusted staff workflow: register one existing patient in this app.
  Future<Profile> enrolInCurrentApp({
    required String profileId,
    required String accountNumber,
    required Map<String, Object?> authorization,
  }) async {
    if (isContactScoped) {
      throw StateError('Only app staff can enrol an existing Health Profile.');
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final profile = await _service.enrolInCurrentApp(
        profileId: profileId,
        accountNumber: accountNumber,
        authorization: authorization,
      );
      await load();
      state = state.copyWith(isSaving: false, clearError: true);
      return profile;
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to enrol Health Profile: $error',
      );
      rethrow;
    }
  }

  /// Staff-only cross-app release. The backend independently checks role,
  /// consent approval, Contact relationship and destination eligibility.
  Future<Profile> addAppEnrolment({
    required String profileId,
    required String destinationAppId,
    required String accountNumber,
    required String authorizationReference,
  }) async {
    if (isContactScoped) {
      throw StateError('Only app staff may manage profile enrolments.');
    }
    if (state.isSaving) throw StateError('Another update is in progress.');
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final profile = await _service.addAppEnrolment(
        profileId: profileId,
        destinationAppId: destinationAppId,
        accountNumber: accountNumber,
        authorizationReference: authorizationReference,
      );
      if (mounted) {
        state = state.copyWith(
          items: _upsertProfile(state.items, profile),
          isSaving: false,
          clearError: true,
        );
      }
      return profile;
    } catch (error) {
      if (mounted) {
        state = state.copyWith(
          isSaving: false,
          error: 'Could not add application enrolment: $error',
        );
      }
      rethrow;
    }
  }

  /// Staff-only removal. Current-app removal is rejected by the API.
  Future<Profile> removeAppEnrolment({
    required String profileId,
    required String targetAppId,
    required String reason,
  }) async {
    if (isContactScoped) {
      throw StateError('Only app staff may manage profile enrolments.');
    }
    if (state.isSaving) throw StateError('Another update is in progress.');
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final profile = await _service.removeAppEnrolment(
        profileId: profileId,
        targetAppId: targetAppId,
        reason: reason,
      );
      if (mounted) {
        state = state.copyWith(
          items: _upsertProfile(state.items, profile),
          isSaving: false,
          clearError: true,
        );
      }
      return profile;
    } catch (error) {
      if (mounted) {
        state = state.copyWith(
          isSaving: false,
          error: 'Could not remove application enrolment: $error',
        );
      }
      rethrow;
    }
  }

  /// Owner-only cross-app access. Do not gate this with isContactScoped:
  /// the backend authenticates the owner and verifies an active SELF link.
  Future<ProfileSharingOptions> eligibleOwnApps(String profileId) =>
      _service.eligibleSelfApps(profileId);

  Future<void> shareOwnProfile({
    required String profileId,
    required String destinationAppId,
    required String consentVersion,
    required String revision,
  }) async {
    await _service.shareOwnProfile(
      profileId: profileId,
      destinationAppId: destinationAppId,
      consentVersion: consentVersion,
      revision: revision,
    );
    state = state.copyWith(items: const [], linkRequests: const []);
  }

  Future<void> revokeOwnProfileApp({
    required String profileId,
    required String targetAppId,
  }) async {
    await _service.revokeOwnProfileApp(
      profileId: profileId,
      targetAppId: targetAppId,
    );
    state = state.copyWith(items: const [], linkRequests: const []);
  }

  Future<void> permanentlyDelete(
    String profileId, {
    required String confirmation,
    required String reason,
    required bool retentionReviewed,
  }) async {
    if (isContactScoped) {
      throw StateError(
        'Permanent deletion is restricted to platform administration.',
      );
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _service.permanentlyDelete(
        profileId,
        confirmation: confirmation,
        reason: reason,
        retentionReviewed: retentionReviewed,
      );
      state = state.copyWith(
        items: state.items
            .where((p) => p.profileId != profileId)
            .toList(growable: false),
        isSaving: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        error: 'Permanent deletion failed: $error',
      );
      rethrow;
    }
  }

  /// Deactivates a Health Profile, keeping it visible when viewing all/inactive.
  Future<void> deactivate(String profileId) async {
    if (isContactScoped) {
      throw StateError('Only unscoped staff may deactivate a profile.');
    }
    Profile? profile;
    for (final item in state.items) {
      if (item.profileId == profileId) {
        profile = item;
        break;
      }
    }
    if (profile?.isMultiApp == true) {
      throw StateError(
        'This Health Profile belongs to multiple applications. '
        'Global deactivation is not available here.',
      );
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _service.deactivate(profileId);
      await load();
      state = state.copyWith(isSaving: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to deactivate profile: $e',
      );
      rethrow;
    }
  }

  /// Restores the profile record, not any previously disabled contact links.
  Future<Profile> reactivate(String profileId) async {
    if (isContactScoped) {
      throw StateError('Only unscoped staff may reactivate a profile.');
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final profile = await _service.reactivate(profileId);
      await load();
      state = state.copyWith(isSaving: false, clearError: true);
      return profile;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to reactivate profile: $e',
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
    required String accountNumber,
  }) async {
    if (isContactScoped) {
      throw StateError('Scoped member views cannot delink arbitrary contacts.');
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final updated = await _service.delinkContact(
        profileId: profileId,
        accountNumber: accountNumber,
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
    String? accountNumber,
    String? contactDisplayName,
    ProfileContactRelationship? relationship,
  }) {
    final resolvedAccountNumber =
        nullable(accountNumber) ?? request.targetAccountNumber;
    return approveLinkRequest(
      request.requestId,
      ProfileLinkRequestApproveInput(
        accountNumber: nullable(resolvedAccountNumber),
        contactDisplayName:
            nullable(contactDisplayName) ?? request.targetContactDisplayName,
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

  void _requireMemberAccount() {
    if (_memberMode && _fixedAccountNumber == null) {
      throw StateError(
        'A verified Native Contact account is required in member mode.',
      );
    }
  }

  ProfileUpsertInput _withFixedContact(ProfileUpsertInput input) {
    if (_fixedAccountNumber == null) return input;

    return ProfileUpsertInput(
      fullName: input.fullName,
      dob: input.dob,
      gender: input.gender,
      accountNumber: _fixedAccountNumber,
      relationship: input.relationship,
      phone: input.phone,
      email: input.email,
      nationalId: input.nationalId,
      notes: input.notes,
      pastMedicalHistory: input.pastMedicalHistory,
      surgicalHistory: input.surgicalHistory,
      familyHistory: input.familyHistory,
      socialHistory: input.socialHistory,
      currentMedications: input.currentMedications,
      allergyStatus: input.allergyStatus,
      allergies: input.allergies,
      conditions: input.conditions,
      vaccinations: input.vaccinations,
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
