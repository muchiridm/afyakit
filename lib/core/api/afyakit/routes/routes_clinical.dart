part of 'routes.dart';

extension AfyaKitClinicalRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 📄 Clinical / Prescriptions
  // ─────────────────────────────────────────────

  /// GET /clinical/prescriptions?profile_id=...
  Uri clinicalPrescriptionsList({
    String? profileId,
    bool? isActive,
    String? status,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final pid = (profileId ?? '').trim();

    if (pid.isNotEmpty) {
      query['profile_id'] = pid;
    }

    final st = (status ?? '').trim();

    if (st.isNotEmpty) {
      query['status'] = st;
    }

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('clinical/prescriptions', query: query);
  }

  /// GET /clinical/profiles/:profileId/prescriptions
  Uri clinicalProfilePrescriptionsList({
    required String profileId,
    bool? isActive,
    String? status,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final st = (status ?? '').trim();

    if (st.isNotEmpty) {
      query['status'] = st;
    }

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri(
      'clinical/profiles/${_seg(profileId)}/prescriptions',
      query: query,
    );
  }

  /// GET /clinical/profiles/:profileId/prescriptions/:prescriptionId
  Uri clinicalProfilePrescriptionGet({
    required String profileId,
    required String prescriptionId,
  }) {
    return _uri(
      'clinical/profiles/${_seg(profileId)}/prescriptions/${_seg(prescriptionId)}',
    );
  }

  /// POST /clinical/profiles/:profileId/prescriptions
  Uri clinicalProfilePrescriptionCreate(String profileId) =>
      _uri('clinical/profiles/${_seg(profileId)}/prescriptions');

  /// PATCH /clinical/profiles/:profileId/prescriptions/:prescriptionId/approve
  Uri clinicalProfilePrescriptionApprove({
    required String profileId,
    required String prescriptionId,
  }) {
    return _uri(
      'clinical/profiles/${_seg(profileId)}/prescriptions/${_seg(prescriptionId)}/approve',
    );
  }

  /// PUT /clinical/profiles/:profileId/prescriptions/:prescriptionId
  Uri clinicalProfilePrescriptionUpdate({
    required String profileId,
    required String prescriptionId,
  }) {
    return _uri(
      'clinical/profiles/${_seg(profileId)}/prescriptions/${_seg(prescriptionId)}',
    );
  }

  /// DELETE /clinical/profiles/:profileId/prescriptions/:prescriptionId
  Uri clinicalProfilePrescriptionDelete({
    required String profileId,
    required String prescriptionId,
  }) {
    return _uri(
      'clinical/profiles/${_seg(profileId)}/prescriptions/${_seg(prescriptionId)}',
    );
  }
}
