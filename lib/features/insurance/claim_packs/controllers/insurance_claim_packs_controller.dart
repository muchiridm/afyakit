// lib/features/insurance/claim_packs/controllers/insurance_claim_packs_controller.dart

import 'package:afyakit/features/insurance/claim_packs/models/insurance_claim_pack.dart';
import 'package:afyakit/features/insurance/claim_packs/services/insurance_claim_packs_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final insuranceClaimPacksControllerProvider =
    StateNotifierProvider<
      InsuranceClaimPacksController,
      InsuranceClaimPacksState
    >((ref) => InsuranceClaimPacksController(ref));

class InsuranceClaimPacksState {
  const InsuranceClaimPacksState({
    this.items = const <InsuranceClaimPack>[],
    this.selected,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<InsuranceClaimPack> items;
  final InsuranceClaimPack? selected;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  InsuranceClaimPacksState copyWith({
    List<InsuranceClaimPack>? items,
    InsuranceClaimPack? selected,
    bool clearSelected = false,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return InsuranceClaimPacksState(
      items: items ?? this.items,
      selected: clearSelected ? null : selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }

  List<InsuranceClaimPack> visibleActiveItems({
    String? profileId,
    String? membershipId,
    String? invoiceId,
    Set<String>? allowedProfileIds,
  }) {
    final String cleanProfileId = _clean(profileId);
    final String cleanMembershipId = _clean(membershipId);
    final String cleanInvoiceId = _clean(invoiceId);

    return items
        .where((InsuranceClaimPack pack) {
          if (!pack.isActive) return false;

          if (cleanProfileId.isNotEmpty &&
              pack.profileId.trim() != cleanProfileId) {
            return false;
          }

          if (cleanMembershipId.isNotEmpty &&
              pack.membershipId.trim() != cleanMembershipId) {
            return false;
          }

          if (cleanInvoiceId.isNotEmpty &&
              (pack.invoiceId ?? '').trim() != cleanInvoiceId) {
            return false;
          }

          if (allowedProfileIds != null) {
            if (allowedProfileIds.isEmpty) return false;

            if (!allowedProfileIds.contains(pack.profileId.trim())) {
              return false;
            }
          }

          return true;
        })
        .toList(growable: false);
  }

  int visibleActiveCount({
    String? profileId,
    String? membershipId,
    String? invoiceId,
    Set<String>? allowedProfileIds,
  }) {
    return visibleActiveItems(
      profileId: profileId,
      membershipId: membershipId,
      invoiceId: invoiceId,
      allowedProfileIds: allowedProfileIds,
    ).length;
  }

  static String _clean(String? value) => (value ?? '').trim();
}

class InsuranceClaimPacksController
    extends StateNotifier<InsuranceClaimPacksState> {
  InsuranceClaimPacksController(this.ref)
    : super(const InsuranceClaimPacksState());

  final Ref ref;

  Future<InsuranceClaimPacksService> get _service {
    return ref.read(insuranceClaimPacksServiceProvider.future);
  }

  Future<void> load({
    String? search,
    String? membershipId,
    String? profileId,
    String? payerContactId,
    String? invoiceId,
    String? memberNo,
    String? authCode,
    String? insurerClaimNo,
    String? visitNo,
    String? prescriptionId,
    InsuranceClaimPackStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final InsuranceClaimPacksService svc = await _service;

      final List<InsuranceClaimPack> items = await svc.list(
        search: search,
        membershipId: membershipId,
        profileId: profileId,
        payerContactId: payerContactId,
        invoiceId: invoiceId,
        memberNo: memberNo,
        authCode: authCode,
        insurerClaimNo: insurerClaimNo,
        visitNo: visitNo,
        prescriptionId: prescriptionId,
        status: status,
        isActive: isActive,
        perPage: perPage,
        page: page,
      );

      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadForProfile({
    required String profileId,
    String? search,
    String? membershipId,
    String? payerContactId,
    String? invoiceId,
    String? memberNo,
    String? authCode,
    String? insurerClaimNo,
    String? visitNo,
    String? prescriptionId,
    InsuranceClaimPackStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      state = state.copyWith(error: 'Profile ID is empty');
      return;
    }

    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final InsuranceClaimPacksService svc = await _service;

      final List<InsuranceClaimPack> items = await svc.listForProfile(
        profileId: cleanProfileId,
        search: search,
        membershipId: membershipId,
        payerContactId: payerContactId,
        invoiceId: invoiceId,
        memberNo: memberNo,
        authCode: authCode,
        insurerClaimNo: insurerClaimNo,
        visitNo: visitNo,
        prescriptionId: prescriptionId,
        status: status,
        isActive: isActive,
        perPage: perPage,
        page: page,
      );

      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadForInvoice(String invoiceId) {
    return load(invoiceId: invoiceId);
  }

  Future<void> loadForMembership(String membershipId) {
    return load(membershipId: membershipId);
  }

  Future<InsuranceClaimPack?> get({
    required String profileId,
    required String claimPackId,
  }) async {
    final String cleanProfileId = profileId.trim();
    final String cleanClaimPackId = claimPackId.trim();

    if (cleanProfileId.isEmpty) {
      state = state.copyWith(error: 'Profile ID is empty');
      return null;
    }

    if (cleanClaimPackId.isEmpty) {
      state = state.copyWith(error: 'Claim Pack ID is empty');
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final InsuranceClaimPacksService svc = await _service;

      final InsuranceClaimPack claimPack = await svc.get(
        profileId: cleanProfileId,
        claimPackId: cleanClaimPackId,
      );

      state = state.copyWith(
        selected: claimPack,
        isLoading: false,
        clearError: true,
      );

      return claimPack;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<InsuranceClaimPack?> create({
    required String profileId,
    required InsuranceClaimPackCreateInput input,
  }) async {
    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      state = state.copyWith(error: 'Profile ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceClaimPacksService svc = await _service;

      final InsuranceClaimPack claimPack = await svc.create(
        profileId: cleanProfileId,
        input: input,
      );

      state = state.copyWith(
        isSaving: false,
        selected: claimPack,
        items: <InsuranceClaimPack>[claimPack, ...state.items],
        clearError: true,
      );

      return claimPack;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<InsuranceClaimPack?> update({
    required String profileId,
    required String claimPackId,
    required InsuranceClaimPackUpdateInput input,
  }) async {
    final String cleanProfileId = profileId.trim();
    final String cleanClaimPackId = claimPackId.trim();

    if (cleanProfileId.isEmpty) {
      state = state.copyWith(error: 'Profile ID is empty');
      return null;
    }

    if (cleanClaimPackId.isEmpty) {
      state = state.copyWith(error: 'Claim Pack ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceClaimPacksService svc = await _service;

      final InsuranceClaimPack claimPack = await svc.update(
        profileId: cleanProfileId,
        claimPackId: cleanClaimPackId,
        input: input,
      );

      _patchClaimPackInState(claimPack);

      return claimPack;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<bool> delete({
    required String profileId,
    required String claimPackId,
  }) async {
    final String cleanProfileId = profileId.trim();
    final String cleanClaimPackId = claimPackId.trim();

    if (cleanProfileId.isEmpty) {
      state = state.copyWith(error: 'Profile ID is empty');
      return false;
    }

    if (cleanClaimPackId.isEmpty) {
      state = state.copyWith(error: 'Claim Pack ID is empty');
      return false;
    }

    if (state.isSaving) return false;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceClaimPacksService svc = await _service;

      await svc.delete(
        profileId: cleanProfileId,
        claimPackId: cleanClaimPackId,
      );

      final List<InsuranceClaimPack> updatedItems = state.items
          .where(
            (InsuranceClaimPack item) => item.claimPackId != cleanClaimPackId,
          )
          .toList(growable: false);

      state = state.copyWith(
        isSaving: false,
        items: updatedItems,
        clearSelected: state.selected?.claimPackId == cleanClaimPackId,
        clearError: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  void _patchClaimPackInState(InsuranceClaimPack claimPack) {
    final bool exists = state.items.any(
      (InsuranceClaimPack item) => item.claimPackId == claimPack.claimPackId,
    );

    final List<InsuranceClaimPack> updatedItems = exists
        ? state.items
              .map(
                (InsuranceClaimPack item) =>
                    item.claimPackId == claimPack.claimPackId
                    ? claimPack
                    : item,
              )
              .toList(growable: false)
        : <InsuranceClaimPack>[claimPack, ...state.items];

    state = state.copyWith(
      isSaving: false,
      selected: claimPack,
      items: updatedItems,
      clearError: true,
    );
  }
}
