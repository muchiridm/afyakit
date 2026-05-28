// lib/features/insurance/claims/controllers/insurance_claims_controller.dart

import 'package:afyakit/features/insurance/claims/models/insurance_claim.dart';
import 'package:afyakit/features/insurance/claims/services/insurance_claims_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final insuranceClaimsControllerProvider =
    StateNotifierProvider<InsuranceClaimsController, InsuranceClaimsState>(
      (ref) => InsuranceClaimsController(ref),
    );

class InsuranceClaimsState {
  const InsuranceClaimsState({
    this.items = const <InsuranceClaim>[],
    this.selected,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<InsuranceClaim> items;
  final InsuranceClaim? selected;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  InsuranceClaimsState copyWith({
    List<InsuranceClaim>? items,
    InsuranceClaim? selected,
    bool clearSelected = false,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return InsuranceClaimsState(
      items: items ?? this.items,
      selected: clearSelected ? null : selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class InsuranceClaimsController extends StateNotifier<InsuranceClaimsState> {
  InsuranceClaimsController(this.ref) : super(const InsuranceClaimsState());

  final Ref ref;

  Future<InsuranceClaimsService> get _service {
    return ref.read(insuranceClaimsServiceProvider.future);
  }

  Future<void> load({
    String? search,
    String? membershipId,
    String? patientId,
    String? patientNo,
    String? payerContactId,
    String? invoiceId,
    String? memberNo,
    String? scheme,
    String? authCode,
    String? claimNo,
    String? visitNo,
    String? prescriptionNo,
    String? prescriptionId,
    InsuranceClaimStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final svc = await _service;

      final items = await svc.list(
        search: search,
        membershipId: membershipId,
        patientId: patientId,
        patientNo: patientNo,
        payerContactId: payerContactId,
        invoiceId: invoiceId,
        memberNo: memberNo,
        scheme: scheme,
        authCode: authCode,
        claimNo: claimNo,
        visitNo: visitNo,
        prescriptionNo: prescriptionNo,
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

  Future<InsuranceClaim?> get(String claimId) async {
    final id = claimId.trim();

    if (id.isEmpty) {
      state = state.copyWith(error: 'Claim ID is empty');
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final svc = await _service;
      final claim = await svc.get(id);

      state = state.copyWith(
        selected: claim,
        isLoading: false,
        clearError: true,
      );

      return claim;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<InsuranceClaim?> create(InsuranceClaimUpsertInput input) async {
    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final svc = await _service;
      final claim = await svc.create(input);

      state = state.copyWith(
        isSaving: false,
        selected: claim,
        items: [claim, ...state.items],
        clearError: true,
      );

      return claim;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<InsuranceClaim?> update(
    String claimId,
    InsuranceClaimUpsertInput input,
  ) async {
    final id = claimId.trim();

    if (id.isEmpty) {
      state = state.copyWith(error: 'Claim ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final svc = await _service;
      final claim = await svc.update(id, input);

      _patchClaimInState(claim);

      return claim;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<bool> delete(String claimId) async {
    final id = claimId.trim();

    if (id.isEmpty) {
      state = state.copyWith(error: 'Claim ID is empty');
      return false;
    }

    if (state.isSaving) return false;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final svc = await _service;
      await svc.delete(id);

      final updatedItems = state.items
          .where((item) => item.claimId != id)
          .toList(growable: false);

      state = state.copyWith(
        isSaving: false,
        items: updatedItems,
        clearSelected: state.selected?.claimId == id,
        clearError: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<InsuranceClaim?> attachClaimForm({
    required String claimId,
    required ClaimFormAttachmentInput input,
  }) async {
    final id = claimId.trim();

    if (id.isEmpty) {
      state = state.copyWith(error: 'Claim ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final svc = await _service;
      final claim = await svc.attachClaimForm(claimId: id, input: input);

      _patchClaimInState(claim);

      return claim;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<InsuranceClaim?> detachClaimForm(String claimId) async {
    final id = claimId.trim();

    if (id.isEmpty) {
      state = state.copyWith(error: 'Claim ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final svc = await _service;
      final claim = await svc.detachClaimForm(id);

      _patchClaimInState(claim);

      return claim;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<InsuranceClaim?> attachPrescription({
    required String claimId,
    required ClaimPrescriptionAttachmentInput input,
  }) async {
    final id = claimId.trim();

    if (id.isEmpty) {
      state = state.copyWith(error: 'Claim ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final svc = await _service;
      final claim = await svc.attachPrescription(claimId: id, input: input);

      _patchClaimInState(claim);

      return claim;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<InsuranceClaim?> detachPrescription(String claimId) async {
    final id = claimId.trim();

    if (id.isEmpty) {
      state = state.copyWith(error: 'Claim ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final svc = await _service;
      final claim = await svc.detachPrescription(id);

      _patchClaimInState(claim);

      return claim;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  void _patchClaimInState(InsuranceClaim claim) {
    final exists = state.items.any((item) => item.claimId == claim.claimId);

    final updatedItems = exists
        ? state.items
              .map((item) => item.claimId == claim.claimId ? claim : item)
              .toList(growable: false)
        : [claim, ...state.items];

    state = state.copyWith(
      isSaving: false,
      selected: claim,
      items: updatedItems,
      clearError: true,
    );
  }
}
