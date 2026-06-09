// lib/features/insurance/documents/controllers/insurance_documents_controller.dart

import 'package:afyakit/features/insurance/documents/models/insurance_document.dart';
import 'package:afyakit/features/insurance/documents/services/insurance_documents_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final insuranceDocumentsControllerProvider =
    StateNotifierProvider<
      InsuranceDocumentsController,
      InsuranceDocumentsState
    >((ref) => InsuranceDocumentsController(ref));

class InsuranceDocumentsState {
  const InsuranceDocumentsState({
    this.items = const <InsuranceDocument>[],
    this.selected,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<InsuranceDocument> items;
  final InsuranceDocument? selected;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  InsuranceDocumentsState copyWith({
    List<InsuranceDocument>? items,
    InsuranceDocument? selected,
    bool clearSelected = false,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return InsuranceDocumentsState(
      items: items ?? this.items,
      selected: clearSelected ? null : selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }

  List<InsuranceDocument> activeForClaimPack(String claimPackId) {
    final String cleanClaimPackId = claimPackId.trim();

    if (cleanClaimPackId.isEmpty) return const <InsuranceDocument>[];

    return items
        .where(
          (InsuranceDocument document) =>
              document.isActive &&
              (document.claimPackId ?? '').trim() == cleanClaimPackId,
        )
        .toList(growable: false);
  }
}

class InsuranceDocumentsController
    extends StateNotifier<InsuranceDocumentsState> {
  InsuranceDocumentsController(this.ref)
    : super(const InsuranceDocumentsState());

  final Ref ref;

  Future<InsuranceDocumentsService> get _service {
    return ref.read(insuranceDocumentsServiceProvider.future);
  }

  Future<void> load({
    String? search,
    String? patientId,
    String? claimPackId,
    InsuranceDocumentType? documentType,
    String? membershipId,
    String? payerContactId,
    InsuranceDocumentStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final InsuranceDocumentsService svc = await _service;

      final List<InsuranceDocument> items = await svc.list(
        search: search,
        patientId: patientId,
        claimPackId: claimPackId,
        documentType: documentType,
        membershipId: membershipId,
        payerContactId: payerContactId,
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
    String? claimPackId,
    InsuranceDocumentType? documentType,
    String? membershipId,
    String? payerContactId,
    InsuranceDocumentStatus? status,
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
      final InsuranceDocumentsService svc = await _service;

      final List<InsuranceDocument> items = await svc.listForPatient(
        patientId: cleanPatientId,
        search: search,
        claimPackId: claimPackId,
        documentType: documentType,
        membershipId: membershipId,
        payerContactId: payerContactId,
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

  Future<void> loadForClaimPack({
    required String patientId,
    required String claimPackId,
    int perPage = 100,
    int page = 1,
  }) {
    return loadForPatient(
      patientId: patientId,
      claimPackId: claimPackId,
      isActive: true,
      perPage: perPage,
      page: page,
    );
  }

  Future<InsuranceDocument?> get({
    required String patientId,
    required String documentId,
  }) async {
    final String cleanPatientId = patientId.trim();
    final String cleanDocumentId = documentId.trim();

    if (cleanPatientId.isEmpty) {
      state = state.copyWith(error: 'Patient ID is empty');
      return null;
    }

    if (cleanDocumentId.isEmpty) {
      state = state.copyWith(error: 'Document ID is empty');
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final InsuranceDocumentsService svc = await _service;

      final InsuranceDocument document = await svc.get(
        patientId: cleanPatientId,
        documentId: cleanDocumentId,
      );

      state = state.copyWith(
        selected: document,
        isLoading: false,
        clearError: true,
      );

      return document;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<InsuranceDocument?> create({
    required String patientId,
    required InsuranceDocumentCreateInput input,
  }) async {
    final String cleanPatientId = patientId.trim();

    if (cleanPatientId.isEmpty) {
      state = state.copyWith(error: 'Patient ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceDocumentsService svc = await _service;

      final InsuranceDocument document = await svc.create(
        patientId: cleanPatientId,
        input: input,
      );

      _patchDocumentInState(document);

      return document;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<InsuranceDocument?> update({
    required String patientId,
    required String documentId,
    required InsuranceDocumentUpdateInput input,
  }) async {
    final String cleanPatientId = patientId.trim();
    final String cleanDocumentId = documentId.trim();

    if (cleanPatientId.isEmpty) {
      state = state.copyWith(error: 'Patient ID is empty');
      return null;
    }

    if (cleanDocumentId.isEmpty) {
      state = state.copyWith(error: 'Document ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceDocumentsService svc = await _service;

      final InsuranceDocument document = await svc.update(
        patientId: cleanPatientId,
        documentId: cleanDocumentId,
        input: input,
      );

      _patchDocumentInState(document);

      return document;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<bool> delete({
    required String patientId,
    required String documentId,
  }) async {
    final String cleanPatientId = patientId.trim();
    final String cleanDocumentId = documentId.trim();

    if (cleanPatientId.isEmpty) {
      state = state.copyWith(error: 'Patient ID is empty');
      return false;
    }

    if (cleanDocumentId.isEmpty) {
      state = state.copyWith(error: 'Document ID is empty');
      return false;
    }

    if (state.isSaving) return false;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceDocumentsService svc = await _service;

      await svc.delete(patientId: cleanPatientId, documentId: cleanDocumentId);

      final List<InsuranceDocument> updatedItems = state.items
          .where((InsuranceDocument item) => item.documentId != cleanDocumentId)
          .toList(growable: false);

      state = state.copyWith(
        isSaving: false,
        items: updatedItems,
        clearSelected: state.selected?.documentId == cleanDocumentId,
        clearError: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<InsuranceDocument?> uploadDocumentFileAndCreate({
    required String patientId,
    required PickedInsuranceDocumentFile file,
    required InsuranceDocumentType documentType,
    String? claimPackId,
    String? membershipId,
    String? payerContactId,
    String? payerDisplayName,
    String? title,
    String? notes,
    InsuranceDocumentStatus? status,
    bool? isActive,
  }) async {
    final String cleanPatientId = patientId.trim();

    if (cleanPatientId.isEmpty) {
      state = state.copyWith(error: 'Patient ID is empty');
      return null;
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final InsuranceDocumentsService svc = await _service;

      final InsuranceDocument document = await svc.uploadDocumentFileAndCreate(
        patientId: cleanPatientId,
        file: file,
        documentType: documentType,
        claimPackId: claimPackId,
        membershipId: membershipId,
        payerContactId: payerContactId,
        payerDisplayName: payerDisplayName,
        title: title,
        notes: notes,
        status: status,
        isActive: isActive,
      );

      _patchDocumentInState(document);

      return document;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  void _patchDocumentInState(InsuranceDocument document) {
    final bool exists = state.items.any(
      (InsuranceDocument item) => item.documentId == document.documentId,
    );

    final List<InsuranceDocument> updatedItems = exists
        ? state.items
              .map(
                (InsuranceDocument item) =>
                    item.documentId == document.documentId ? document : item,
              )
              .toList(growable: false)
        : <InsuranceDocument>[document, ...state.items];

    state = state.copyWith(
      isSaving: false,
      selected: document,
      items: updatedItems,
      clearError: true,
    );
  }
}
