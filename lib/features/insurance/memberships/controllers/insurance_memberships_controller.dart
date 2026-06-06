// lib/features/insurance/memberships/controllers/insurance_memberships_controller.dart

import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:afyakit/features/insurance/memberships/services/insurance_memberships_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final insuranceMembershipsControllerProvider =
    StateNotifierProvider<
      InsuranceMembershipsController,
      InsuranceMembershipsState
    >((ref) => InsuranceMembershipsController(ref));

class InsuranceMembershipsState {
  const InsuranceMembershipsState({
    this.items = const <InsuranceMembership>[],
    this.selected,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<InsuranceMembership> items;
  final InsuranceMembership? selected;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  InsuranceMembershipsState copyWith({
    List<InsuranceMembership>? items,
    InsuranceMembership? selected,
    bool clearSelected = false,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return InsuranceMembershipsState(
      items: items ?? this.items,
      selected: clearSelected ? null : selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }

  List<InsuranceMembership> visibleActiveItems({
    String? patientId,
    Set<String>? allowedPatientIds,
  }) {
    final String cleanPatientId = _clean(patientId);

    return items
        .where((InsuranceMembership membership) {
          if (!membership.isActive) return false;

          if (cleanPatientId.isNotEmpty &&
              membership.patientId.trim() != cleanPatientId) {
            return false;
          }

          if (allowedPatientIds != null) {
            if (allowedPatientIds.isEmpty) return false;

            if (!allowedPatientIds.contains(membership.patientId.trim())) {
              return false;
            }
          }

          return true;
        })
        .toList(growable: false);
  }

  int visibleActiveCount({String? patientId, Set<String>? allowedPatientIds}) {
    return visibleActiveItems(
      patientId: patientId,
      allowedPatientIds: allowedPatientIds,
    ).length;
  }

  static String _clean(String? value) => (value ?? '').trim();
}

class InsuranceMembershipsController
    extends StateNotifier<InsuranceMembershipsState> {
  InsuranceMembershipsController(this.ref)
    : super(const InsuranceMembershipsState());

  final Ref ref;

  Future<InsuranceMembershipsService> get _service async {
    return ref.read(insuranceMembershipsServiceProvider.future);
  }

  Future<void> load({
    String? search,
    String? patientId,
    String? patientNo,
    String? payerContactId,
    String? memberNo,
    String? scheme,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final InsuranceMembershipsService svc = await _service;

      final List<InsuranceMembership> items = await svc.list(
        search: search,
        patientId: patientId,
        patientNo: patientNo,
        payerContactId: payerContactId,
        memberNo: memberNo,
        scheme: scheme,
        isActive: isActive,
        perPage: perPage,
        page: page,
      );

      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  @Deprecated('Use load(memberNo: ...) instead.')
  Future<void> loadLegacy({
    String? search,
    String? patientId,
    String? patientNo,
    String? payerContactId,
    String? memberNumber,
    String? scheme,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    return load(
      search: search,
      patientId: patientId,
      patientNo: patientNo,
      payerContactId: payerContactId,
      memberNo: memberNumber,
      scheme: scheme,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );
  }

  Future<void> loadForPatient(String patientId) {
    return load(patientId: patientId, isActive: true);
  }

  Future<InsuranceMembership?> get(String membershipId) async {
    final String id = membershipId.trim();

    if (id.isEmpty) {
      state = state.copyWith(error: 'Membership ID is empty');
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final InsuranceMembershipsService svc = await _service;
      final InsuranceMembership membership = await svc.get(id);

      state = state.copyWith(selected: membership, isLoading: false);
      return membership;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<InsuranceMembership?> create(
    InsuranceMembershipUpsertInput input,
  ) async {
    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceMembershipsService svc = await _service;
      final InsuranceMembership membership = await svc.create(input);

      state = state.copyWith(
        isSaving: false,
        selected: membership,
        items: <InsuranceMembership>[membership, ...state.items],
      );

      return membership;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<InsuranceMembership?> update(
    String membershipId,
    InsuranceMembershipUpsertInput input,
  ) async {
    final String id = membershipId.trim();

    if (id.isEmpty) {
      state = state.copyWith(error: 'Membership ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceMembershipsService svc = await _service;
      final InsuranceMembership membership = await svc.update(id, input);

      final List<InsuranceMembership> updatedItems = state.items
          .map((InsuranceMembership item) {
            if (item.membershipId == membership.membershipId) {
              return membership;
            }

            return item;
          })
          .toList(growable: false);

      state = state.copyWith(
        isSaving: false,
        selected: membership,
        items: updatedItems,
      );

      return membership;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<bool> delete(String membershipId) async {
    final String id = membershipId.trim();

    if (id.isEmpty) {
      state = state.copyWith(error: 'Membership ID is empty');
      return false;
    }

    if (state.isSaving) return false;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceMembershipsService svc = await _service;
      await svc.delete(id);

      final List<InsuranceMembership> updatedItems = state.items
          .where((InsuranceMembership item) => item.membershipId != id)
          .toList(growable: false);

      state = state.copyWith(
        isSaving: false,
        items: updatedItems,
        clearSelected: state.selected?.membershipId == id,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }
}
