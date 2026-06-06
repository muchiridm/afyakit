// lib/features/clinical/prescriptions/controllers/prescriptions_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/services/prescriptions_service.dart';

@immutable
class PrescriptionsState {
  const PrescriptionsState({
    this.items = const <Prescription>[],
    this.patientId,
    this.isLoading = false,
    this.isUploading = false,
    this.isSaving = false,
    this.error,
  });

  final List<Prescription> items;
  final String? patientId;
  final bool isLoading;
  final bool isUploading;
  final bool isSaving;
  final String? error;

  bool get busy => isLoading || isUploading || isSaving;

  PrescriptionsState copyWith({
    List<Prescription>? items,
    String? patientId,
    bool? isLoading,
    bool? isUploading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return PrescriptionsState(
      items: items ?? this.items,
      patientId: patientId ?? this.patientId,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PrescriptionsController extends StateNotifier<PrescriptionsState> {
  PrescriptionsController({
    required PrescriptionsService service,
    String? patientId,
  }) : _service = service,
       super(PrescriptionsState(patientId: patientId));

  final PrescriptionsService _service;

  Future<void> load({
    String? patientId,
    bool? isActive,
    PrescriptionStatus? status,
  }) async {
    final pid = (patientId ?? state.patientId ?? '').trim();

    state = state.copyWith(
      patientId: pid.isEmpty ? null : pid,
      isLoading: true,
      clearError: true,
    );

    try {
      if (pid.isEmpty) {
        state = state.copyWith(
          items: const <Prescription>[],
          patientId: null,
          isLoading: false,
          clearError: true,
        );
        return;
      }

      final items = await _service.list(
        patientId: pid,
        isActive: isActive,
        status: status,
      );

      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> upload({
    required String tenantId,
    required String patientId,
    required PickedPrescriptionFile file,
    String? note,
    String? prescribedOn,
  }) async {
    final pid = patientId.trim();

    if (pid.isEmpty) {
      state = state.copyWith(error: 'Patient ID is required');
      return;
    }

    state = state.copyWith(patientId: pid, isUploading: true, clearError: true);

    try {
      final saved = await _service.uploadAndCreate(
        tenantId: tenantId,
        patientId: pid,
        file: file,
        note: note,
        prescribedOn: prescribedOn,
      );

      final next = <Prescription>[saved, ...state.items]
          .where(
            (Prescription p) => p.patientId == pid || state.patientId == null,
          )
          .toList(growable: false);

      state = state.copyWith(items: next, isUploading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
    }
  }

  Future<Prescription?> approve(Prescription prescription) async {
    final pid = prescription.patientId.trim();
    final rxid = prescription.prescriptionId.trim();

    if (pid.isEmpty) {
      state = state.copyWith(error: 'Patient ID is required');
      return null;
    }

    if (rxid.isEmpty) {
      state = state.copyWith(error: 'Prescription ID is required');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final updated = await _service.approve(
        patientId: pid,
        prescriptionId: rxid,
      );

      _patchInState(updated);

      return updated;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<Prescription?> update({
    required Prescription prescription,
    required PrescriptionUpdateInput input,
  }) async {
    final pid = prescription.patientId.trim();
    final rxid = prescription.prescriptionId.trim();

    if (pid.isEmpty) {
      state = state.copyWith(error: 'Patient ID is required');
      return null;
    }

    if (rxid.isEmpty) {
      state = state.copyWith(error: 'Prescription ID is required');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final updated = await _service.update(
        patientId: pid,
        prescriptionId: rxid,
        input: input,
      );

      _patchInState(updated);

      return updated;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<void> delete(Prescription prescription) async {
    if (state.isSaving || state.isLoading) return;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _service.remove(
        patientId: prescription.patientId,
        prescriptionId: prescription.prescriptionId,
      );

      final next = state.items
          .where(
            (Prescription p) => p.prescriptionId != prescription.prescriptionId,
          )
          .toList(growable: false);

      state = state.copyWith(items: next, isSaving: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  Future<String> downloadUrl(Prescription prescription) {
    return _service.downloadUrl(prescription.storagePath);
  }

  void _patchInState(Prescription prescription) {
    final exists = state.items.any(
      (Prescription p) => p.prescriptionId == prescription.prescriptionId,
    );

    final next = exists
        ? state.items
              .map(
                (Prescription p) =>
                    p.prescriptionId == prescription.prescriptionId
                    ? prescription
                    : p,
              )
              .toList(growable: false)
        : <Prescription>[prescription, ...state.items];

    state = state.copyWith(items: next, isSaving: false, clearError: true);
  }
}
