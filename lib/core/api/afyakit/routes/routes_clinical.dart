part of 'routes.dart';

extension AfyaKitClinicalRoutes on AfyaKitRoutes {
  /// Independent prescription resource; profile_id is a query/body field.
  Uri clinicalPrescriptionsList({
    String? profileId,
    bool? isActive,
    String? status,
    int perPage = 50,
    int page = 1,
  }) => _uri(
    'clinical/prescriptions',
    query: {
      'per_page': '$perPage',
      'page': '$page',
      if (profileId != null && profileId.trim().isNotEmpty)
        'profile_id': profileId.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (isActive != null) 'is_active': '$isActive',
    },
  );

  Uri clinicalPrescriptionCreate() => _uri('clinical/prescriptions');
  Uri clinicalPrescriptionGet(String prescriptionId) =>
      _uri('clinical/prescriptions/${_seg(prescriptionId)}');
  Uri clinicalPrescriptionUpdate(String prescriptionId) =>
      clinicalPrescriptionGet(prescriptionId);
  Uri clinicalPrescriptionDelete(String prescriptionId) =>
      clinicalPrescriptionGet(prescriptionId);
  Uri clinicalPrescriptionApprove(String prescriptionId) =>
      _uri('clinical/prescriptions/${_seg(prescriptionId)}/approve');
  Uri clinicalPrescriptionStorageAccess() =>
      _uri('clinical/prescriptions/storage-access');
  Uri clinicalPrescriptionStorageDownload(String prescriptionId) =>
      _uri('clinical/prescriptions/${_seg(prescriptionId)}/storage-download');

  // Keep existing Dart call signatures while removing all old nested URLs.
  // Create/upload callers must include profile_id in their request body.
  Uri clinicalProfilePrescriptionsList({
    required String profileId,
    bool? isActive,
    String? status,
    int perPage = 50,
    int page = 1,
  }) => clinicalPrescriptionsList(
    profileId: profileId,
    isActive: isActive,
    status: status,
    perPage: perPage,
    page: page,
  );
  Uri clinicalProfilePrescriptionCreate(String profileId) =>
      clinicalPrescriptionCreate();
  Uri clinicalProfilePrescriptionGet({
    required String profileId,
    required String prescriptionId,
  }) => clinicalPrescriptionGet(prescriptionId);
  Uri clinicalProfilePrescriptionUpdate({
    required String profileId,
    required String prescriptionId,
  }) => clinicalPrescriptionUpdate(prescriptionId);
  Uri clinicalProfilePrescriptionDelete({
    required String profileId,
    required String prescriptionId,
  }) => clinicalPrescriptionDelete(prescriptionId);
  Uri clinicalProfilePrescriptionApprove({
    required String profileId,
    required String prescriptionId,
  }) => clinicalPrescriptionApprove(prescriptionId);

  // Clinical notes — all endpoints require app-staff access.
  // GET requires profile_id; encounter_id is optional.
  Uri clinicalNotesList({
    required String profileId,
    String? encounterId,
    int perPage = 50,
    int page = 1,
  }) => _uri(
    'clinical/notes',
    query: {
      'profile_id': profileId,
      'per_page': '$perPage',
      'page': '$page',
      if (encounterId != null && encounterId.trim().isNotEmpty)
        'encounter_id': encounterId.trim(),
    },
  );

  /// POST; request body must contain profile_id, note_type and content.
  Uri clinicalNoteCreate() => _uri('clinical/notes');

  /// GET.
  Uri clinicalNoteGet(String noteId) => _uri('clinical/notes/${_seg(noteId)}');

  /// PATCH; only title, content, observed_at are editable.
  Uri clinicalNoteUpdate(String noteId) => clinicalNoteGet(noteId);

  /// POST.
  Uri clinicalNoteSign(String noteId) =>
      _uri('clinical/notes/${_seg(noteId)}/sign');

  /// POST; body requires reason and content.
  Uri clinicalNoteAmend(String noteId) =>
      _uri('clinical/notes/${_seg(noteId)}/amendments');

  // Clinical tests — all endpoints require app-staff access.
  // GET requires profile_id; encounter_id is optional.
  Uri clinicalTestsList({
    required String profileId,
    String? encounterId,
    int perPage = 50,
    int page = 1,
  }) => _uri(
    'clinical/tests',
    query: {
      'profile_id': profileId,
      'per_page': '$perPage',
      'page': '$page',
      if (encounterId != null && encounterId.trim().isNotEmpty)
        'encounter_id': encounterId.trim(),
    },
  );

  /// POST; body requires profile_id, test_type, name, performed_at, results.
  Uri clinicalTestCreate() => _uri('clinical/tests');

  /// GET.
  Uri clinicalTestGet(String testId) => _uri('clinical/tests/${_seg(testId)}');

  /// PATCH; editable fields: results, interpretation, units, performed_at.
  Uri clinicalTestUpdate(String testId) => clinicalTestGet(testId);

  /// POST.
  Uri clinicalTestSign(String testId) =>
      _uri('clinical/tests/${_seg(testId)}/sign');

  /// POST; body requires reason and changes (a test patch object).
  Uri clinicalTestAmend(String testId) =>
      _uri('clinical/tests/${_seg(testId)}/amendments');
}
