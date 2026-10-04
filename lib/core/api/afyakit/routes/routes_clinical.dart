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

    if (s.isNotEmpty) {
      query['search'] = s;
    }

    final cid = (contactId ?? '').trim();

    if (cid.isNotEmpty) {
      query['contact_id'] = cid;
    }

    final rel = (relationship ?? '').trim();

    if (rel.isNotEmpty) {
      query['relationship'] = rel;
    }

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

    if (s.isNotEmpty) {
      query['status'] = s;
    }

    final pid = (profileId ?? '').trim();

    if (pid.isNotEmpty) {
      query['profile_id'] = pid;
    }

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

  // ─────────────────────────────────────────────
  // 🫀 Clinical / Health Metrics
  // ─────────────────────────────────────────────

  /// GET /clinical/profiles/:profileId/metrics
  Uri clinicalProfileHealthMetricsList(
    String profileId, {
    String? type,
    bool? isActive,
    DateTime? from,
    DateTime? to,
    int? page,
    int? perPage,
  }) {
    return _uri(
      'clinical/profiles/${_seg(profileId)}/metrics',
      query: _clinicalHealthMetricsQuery(
        type: type,
        isActive: isActive,
        from: from,
        to: to,
        page: page,
        perPage: perPage,
      ),
    );
  }

  /// GET /clinical/profiles/:profileId/metrics/:metricId
  Uri clinicalProfileHealthMetricGet({
    required String profileId,
    required String metricId,
  }) {
    return _uri(
      'clinical/profiles/${_seg(profileId)}/metrics/${_seg(metricId)}',
    );
  }

  /// POST /clinical/profiles/:profileId/metrics
  Uri clinicalProfileHealthMetricCreate(String profileId) {
    return _uri('clinical/profiles/${_seg(profileId)}/metrics');
  }

  /// PUT /clinical/profiles/:profileId/metrics/:metricId
  Uri clinicalProfileHealthMetricUpdate({
    required String profileId,
    required String metricId,
  }) {
    return _uri(
      'clinical/profiles/${_seg(profileId)}/metrics/${_seg(metricId)}',
    );
  }

  /// DELETE /clinical/profiles/:profileId/metrics/:metricId
  Uri clinicalProfileHealthMetricDelete({
    required String profileId,
    required String metricId,
  }) {
    return _uri(
      'clinical/profiles/${_seg(profileId)}/metrics/${_seg(metricId)}',
    );
  }

  /// GET /clinical/metrics?profile_id=...
  Uri clinicalHealthMetricsList({
    String? profileId,
    String? type,
    bool? isActive,
    DateTime? from,
    DateTime? to,
    int? page,
    int? perPage,
  }) {
    return _uri(
      'clinical/metrics',
      query: _clinicalHealthMetricsQuery(
        profileId: profileId,
        type: type,
        isActive: isActive,
        from: from,
        to: to,
        page: page,
        perPage: perPage,
      ),
    );
  }

  Map<String, String>? _clinicalHealthMetricsQuery({
    String? profileId,
    String? type,
    bool? isActive,
    DateTime? from,
    DateTime? to,
    int? page,
    int? perPage,
  }) {
    final query = <String, String>{};

    final cleanProfileId = profileId?.trim();

    if (cleanProfileId != null && cleanProfileId.isNotEmpty) {
      query['profile_id'] = cleanProfileId;
    }

    final cleanType = type?.trim();

    if (cleanType != null && cleanType.isNotEmpty) {
      query['type'] = cleanType;
    }

    if (isActive != null) {
      query['is_active'] = isActive.toString();
    }

    if (from != null) {
      query['from'] = from.toUtc().toIso8601String();
    }

    if (to != null) {
      query['to'] = to.toUtc().toIso8601String();
    }

    if (page != null && page > 0) {
      query['page'] = page.toString();
    }

    if (perPage != null && perPage > 0) {
      query['per_page'] = perPage.toString();
    }

    return query.isEmpty ? null : query;
  }
}
