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
}
