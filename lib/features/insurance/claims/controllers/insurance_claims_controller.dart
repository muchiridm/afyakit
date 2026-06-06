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

  List<InsuranceClaim> visibleActiveItems({
    String? patientId,
    String? membershipId,
    String? invoiceId,
    Set<String>? allowedPatientIds,
  }) {
    final String cleanPatientId = _clean(patientId);
    final String cleanMembershipId = _clean(membershipId);
    final String cleanInvoiceId = _clean(invoiceId);

    return items
        .where((InsuranceClaim claim) {
          if (!claim.isActive) return false;

          if (cleanPatientId.isNotEmpty &&
              claim.patientId.trim() != cleanPatientId) {
            return false;
          }

          if (cleanMembershipId.isNotEmpty &&
              claim.membershipId.trim() != cleanMembershipId) {
            return false;
          }

          if (cleanInvoiceId.isNotEmpty &&
              (claim.invoiceId ?? '').trim() != cleanInvoiceId) {
            return false;
          }

          if (allowedPatientIds != null) {
            if (allowedPatientIds.isEmpty) return false;

            if (!allowedPatientIds.contains(claim.patientId.trim())) {
              return false;
            }
          }

          return true;
        })
        .toList(growable: false);
  }

  int visibleActiveCount({
    String? patientId,
    String? membershipId,
    String? invoiceId,
    Set<String>? allowedPatientIds,
  }) {
    return visibleActiveItems(
      patientId: patientId,
      membershipId: membershipId,
      invoiceId: invoiceId,
      allowedPatientIds: allowedPatientIds,
    ).length;
  }

  static String _clean(String? value) => (value ?? '').trim();
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
    String? payerContactId,
    String? invoiceId,
    String? memberNo,
    String? authCode,
    String? claimNo,
    String? visitNo,
    String? prescriptionId,
    InsuranceClaimStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final InsuranceClaimsService svc = await _service;

      final List<InsuranceClaim> items = await svc.list(
        search: search,
        membershipId: membershipId,
        patientId: patientId,
        payerContactId: payerContactId,
        invoiceId: invoiceId,
        memberNo: memberNo,
        authCode: authCode,
        claimNo: claimNo,
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

  Future<void> loadForPatient({
    required String patientId,
    String? search,
    String? membershipId,
    String? payerContactId,
    String? invoiceId,
    String? memberNo,
    String? authCode,
    String? claimNo,
    String? visitNo,
    String? prescriptionId,
    InsuranceClaimStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final String cleanPatientId = patientId.trim();

    if (cleanPatientId.isEmpty) {
      state = state.copyWith(error: 'Patient ID is empty');
      return;
    }

    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final InsuranceClaimsService svc = await _service;

      final List<InsuranceClaim> items = await svc.listForPatient(
        patientId: cleanPatientId,
        search: search,
        membershipId: membershipId,
        payerContactId: payerContactId,
        invoiceId: invoiceId,
        memberNo: memberNo,
        authCode: authCode,
        claimNo: claimNo,
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

  Future<InsuranceClaim?> get({
    required String patientId,
    required String claimId,
  }) async {
    final String cleanPatientId = patientId.trim();
    final String cleanClaimId = claimId.trim();

    if (cleanPatientId.isEmpty) {
      state = state.copyWith(error: 'Patient ID is empty');
      return null;
    }

    if (cleanClaimId.isEmpty) {
      state = state.copyWith(error: 'Claim ID is empty');
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final InsuranceClaimsService svc = await _service;

      final InsuranceClaim claim = await svc.get(
        patientId: cleanPatientId,
        claimId: cleanClaimId,
      );

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

  Future<InsuranceClaim?> create({
    required String patientId,
    required InsuranceClaimCreateInput input,
  }) async {
    final String cleanPatientId = patientId.trim();

    if (cleanPatientId.isEmpty) {
      state = state.copyWith(error: 'Patient ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceClaimsService svc = await _service;

      final InsuranceClaim claim = await svc.create(
        patientId: cleanPatientId,
        input: input,
      );

      state = state.copyWith(
        isSaving: false,
        selected: claim,
        items: <InsuranceClaim>[claim, ...state.items],
        clearError: true,
      );

      return claim;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<InsuranceClaim?> update({
    required String patientId,
    required String claimId,
    required InsuranceClaimUpdateInput input,
  }) async {
    final String cleanPatientId = patientId.trim();
    final String cleanClaimId = claimId.trim();

    if (cleanPatientId.isEmpty) {
      state = state.copyWith(error: 'Patient ID is empty');
      return null;
    }

    if (cleanClaimId.isEmpty) {
      state = state.copyWith(error: 'Claim ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceClaimsService svc = await _service;

      final InsuranceClaim claim = await svc.update(
        patientId: cleanPatientId,
        claimId: cleanClaimId,
        input: input,
      );

      _patchClaimInState(claim);

      return claim;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<bool> delete({
    required String patientId,
    required String claimId,
  }) async {
    final String cleanPatientId = patientId.trim();
    final String cleanClaimId = claimId.trim();

    if (cleanPatientId.isEmpty) {
      state = state.copyWith(error: 'Patient ID is empty');
      return false;
    }

    if (cleanClaimId.isEmpty) {
      state = state.copyWith(error: 'Claim ID is empty');
      return false;
    }

    if (state.isSaving) return false;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceClaimsService svc = await _service;

      await svc.delete(patientId: cleanPatientId, claimId: cleanClaimId);

      final List<InsuranceClaim> updatedItems = state.items
          .where((InsuranceClaim item) => item.claimId != cleanClaimId)
          .toList(growable: false);

      state = state.copyWith(
        isSaving: false,
        items: updatedItems,
        clearSelected: state.selected?.claimId == cleanClaimId,
        clearError: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<InsuranceClaim?> uploadClaimFileAndCreate({
    required String patientId,
    required String membershipId,
    required PickedInsuranceClaimFile file,
    String? invoiceId,
    String? invoiceNumber,
    String? prescriptionId,
    String? prescriptionNo,
    String? prescriberName,
    String? authCode,
    String? claimNo,
    String? visitNo,
    String? serviceDate,
    String? diagnosis,
    String? icd10Code,
    String? notes,
    InsuranceClaimStatus? status,
    bool? isActive,
  }) async {
    final String cleanPatientId = patientId.trim();
    final String cleanMembershipId = membershipId.trim();

    if (cleanPatientId.isEmpty) {
      state = state.copyWith(error: 'Patient ID is empty');
      return null;
    }

    if (cleanMembershipId.isEmpty) {
      state = state.copyWith(error: 'Membership ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceClaimsService svc = await _service;

      final InsuranceClaim claim = await svc.uploadClaimFileAndCreate(
        patientId: cleanPatientId,
        membershipId: cleanMembershipId,
        file: file,
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        prescriptionId: prescriptionId,
        prescriptionNo: prescriptionNo,
        prescriberName: prescriberName,
        authCode: authCode,
        claimNo: claimNo,
        visitNo: visitNo,
        serviceDate: serviceDate,
        diagnosis: diagnosis,
        icd10Code: icd10Code,
        notes: notes,
        status: status,
        isActive: isActive,
      );

      _patchClaimInState(claim);

      return claim;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  void _patchClaimInState(InsuranceClaim claim) {
    final bool exists = state.items.any(
      (InsuranceClaim item) => item.claimId == claim.claimId,
    );

    final List<InsuranceClaim> updatedItems = exists
        ? state.items
              .map(
                (InsuranceClaim item) =>
                    item.claimId == claim.claimId ? claim : item,
              )
              .toList(growable: false)
        : <InsuranceClaim>[claim, ...state.items];

    state = state.copyWith(
      isSaving: false,
      selected: claim,
      items: updatedItems,
      clearError: true,
    );
  }
}
