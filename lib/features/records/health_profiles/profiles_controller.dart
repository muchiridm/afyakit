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
      accountNumber: clearAccountNumber ? null : (accountNumber ?? this.accountNumber),
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

  bool get isContactScoped => _memberMode || _fixedAccountNumber != null;

  // ─────────────────────────────────────────────
  // Profiles
  // ─────────────────────────────────────────────

  Future<void> load() async {
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

  void setAccountNumber(String? value) {
    if (isContactScoped) return;

    final trimmed = nullable(value);

    state = state.copyWith(accountNumber: trimmed, clearAccountNumber: trimmed == null);
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
          : resetAccountNumber || (accountNumber != null && trimmedAccountNumber == null),
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

  Future<Profile> create(ProfileUpsertInput input) async {
    _requireMemberAccount();
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      if (_memberMode && !const <ProfileContactRelationship>{
        ProfileContactRelationship.self,
        ProfileContactRelationship.child,
        ProfileContactRelationship.parent,
        ProfileContactRelationship.guardian,
      }.contains(input.relationship)) {
        throw StateError('Select Self, Child, Parent or Guardian when creating a member profile.');
      }
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
    String profileId,
    ProfileLinkToSelfInput input,
  ) async {
    _requireMemberAccount();
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final linked = await _service.linkToSelf(profileId, input);
      final items = _upsertProfile(state.items, linked);

      state = state.copyWith(items: items, isSaving: false, clearError: true);

      return linked;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to link Health Profile: $e',
      );
      rethrow;
    }
  }

  Future<Profile> update(String profileId, ProfileUpsertInput input) async {
    _requireMemberAccount();
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final effectiveInput = _withFixedContact(input);
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

  Future<void> remove(String profileId) async {
    _requireMemberAccount();
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _service.remove(profileId);

      final items = state.items
          .where((p) => p.profileId != profileId)
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
