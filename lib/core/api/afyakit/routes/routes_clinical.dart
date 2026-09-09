part of 'routes.dart';

extension AfyaKitClinicalRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🧑‍⚕️ Clinical / Health Profiles
  // ─────────────────────────────────────────────

  Uri clinicalProfilesList({
    String? search,
    String? contactId,
    String? relationship,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final s = (search ?? '').trim();
    if (s.isNotEmpty) query['search'] = s;

    final cid = (contactId ?? '').trim();
    if (cid.isNotEmpty) query['contact_id'] = cid;

    final rel = (relationship ?? '').trim();
    if (rel.isNotEmpty) query['relationship'] = rel;

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('clinical/profiles', query: query);
  }

  /// GET /clinical/profiles/:profileId
  Uri clinicalProfileGet(String profileId) =>
      _uri('clinical/profiles/${_seg(profileId)}');

  /// POST /clinical/profiles
  Uri clinicalProfileCreate() => _uri('clinical/profiles');

  /// PUT /clinical/profiles/:profileId
  Uri clinicalProfileUpdate(String profileId) =>
      _uri('clinical/profiles/${_seg(profileId)}');

  /// DELETE /clinical/profiles/:profileId
  Uri clinicalProfileDelete(String profileId) =>
      _uri('clinical/profiles/${_seg(profileId)}');

  /// POST /clinical/profiles/:profileId/link-self
  Uri clinicalProfileLinkSelf(String profileId) =>
      _uri('clinical/profiles/${_seg(profileId)}/link-self');

  // ─────────────────────────────────────────────
  // 🧾 Clinical / Profile link requests
  // ─────────────────────────────────────────────

  /// POST /clinical/profiles/:profileId/link-requests
  Uri clinicalProfileLinkRequestCreate(String profileId) =>
      _uri('clinical/profiles/${_seg(profileId)}/link-requests');

  /// GET /clinical/profiles/link-requests
  Uri clinicalProfileLinkRequestsList({
    String? status,
    String? profileId,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final s = (status ?? '').trim();
    if (s.isNotEmpty) query['status'] = s;

    final pid = (profileId ?? '').trim();
    if (pid.isNotEmpty) query['profile_id'] = pid;

    return _uri('clinical/profiles/link-requests', query: query);
  }

  /// POST /clinical/profiles/link-requests/:requestId/approve
  Uri clinicalProfileLinkRequestApprove(String requestId) =>
      _uri('clinical/profiles/link-requests/${_seg(requestId)}/approve');

  /// POST /clinical/profiles/link-requests/:requestId/reject
  Uri clinicalProfileLinkRequestReject(String requestId) =>
      _uri('clinical/profiles/link-requests/${_seg(requestId)}/reject');

  // ─────────────────────────────────────────────
  // 🔗 Clinical / Staff direct profile-contact links
  // ─────────────────────────────────────────────

  /// POST /clinical/profiles/:profileId/linked-contacts
  Uri clinicalProfileLinkedContactCreate(String profileId) =>
      _uri('clinical/profiles/${_seg(profileId)}/linked-contacts');

  /// DELETE /clinical/profiles/:profileId/linked-contacts/:contactId
  Uri clinicalProfileLinkedContactDelete({
    required String profileId,
    required String contactId,
  }) {
    return _uri(
      'clinical/profiles/${_seg(profileId)}/linked-contacts/${_seg(contactId)}',
    );
  }

  // ─────────────────────────────────────────────
  // 📄 Clinical / Prescriptions
  // ─────────────────────────────────────────────

  /// Staff global list:
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
    if (pid.isNotEmpty) query['profile_id'] = pid;

    final st = (status ?? '').trim();
    if (st.isNotEmpty) query['status'] = st;

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
    if (st.isNotEmpty) query['status'] = st;

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
