part of 'routes.dart';

extension AfyaKitRecordsRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // Health Profiles
  // ─────────────────────────────────────────────

  Uri recordsProfilesList({
    String? search,
    String? contactId,
    String? relationship,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    return _uri(
      'records/profiles',
      query: _recordsQuery(
        search: search,
        isActive: isActive,
        perPage: perPage,
        page: page,
        extras: {'contact_id': contactId, 'relationship': relationship},
      ),
    );
  }

  Uri recordsProfileGet(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}');

  Uri recordsProfileCreate() => _uri('records/profiles');

  Uri recordsProfileUpdate(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}');

  Uri recordsProfileDelete(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}');

  Uri recordsProfileLinkSelf(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}/link-self');

  // ─────────────────────────────────────────────
  // Profile Link Requests
  // ─────────────────────────────────────────────

  Uri recordsProfileLinkRequestCreate(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}/link-requests');

  Uri recordsProfileLinkRequestsList({
    String? status,
    String? profileId,
    int perPage = 50,
    int page = 1,
  }) {
    return _uri(
      'records/profiles/link-requests',
      query: _recordsQuery(
        perPage: perPage,
        page: page,
        extras: {'status': status, 'profile_id': profileId},
      ),
    );
  }

  Uri recordsProfileLinkRequestApprove(String requestId) =>
      _uri('records/profiles/link-requests/${_seg(requestId)}/approve');

  Uri recordsProfileLinkRequestReject(String requestId) =>
      _uri('records/profiles/link-requests/${_seg(requestId)}/reject');

  // ─────────────────────────────────────────────
  // Linked Contacts
  // ─────────────────────────────────────────────

  Uri recordsProfileLinkedContactCreate(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}/linked-contacts');

  Uri recordsProfileLinkedContactDelete({
    required String profileId,
    required String contactId,
  }) => _uri(
    'records/profiles/${_seg(profileId)}/linked-contacts/'
    '${_seg(contactId)}',
  );

  // ─────────────────────────────────────────────
  // Health Metrics
  // ─────────────────────────────────────────────

  Uri recordsProfileHealthMetricsList(
    String profileId, {
    String? type,
    bool? isActive,
    DateTime? from,
    DateTime? to,
    int? page,
    int? perPage,
  }) {
    return _uri(
      'records/profiles/${_seg(profileId)}/metrics',
      query: _recordsMetricsQuery(
        type: type,
        isActive: isActive,
        from: from,
        to: to,
        page: page,
        perPage: perPage,
      ),
    );
  }

  Uri recordsProfileHealthMetricGet({
    required String profileId,
    required String metricId,
  }) => _uri(
    'records/profiles/${_seg(profileId)}/metrics/'
    '${_seg(metricId)}',
  );

  Uri recordsProfileHealthMetricCreate(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}/metrics');

  Uri recordsProfileHealthMetricUpdate({
    required String profileId,
    required String metricId,
  }) => _uri(
    'records/profiles/${_seg(profileId)}/metrics/'
    '${_seg(metricId)}',
  );

  Uri recordsProfileHealthMetricDelete({
    required String profileId,
    required String metricId,
  }) => _uri(
    'records/profiles/${_seg(profileId)}/metrics/'
    '${_seg(metricId)}',
  );

  Uri recordsHealthMetricsList({
    String? profileId,
    String? type,
    bool? isActive,
    DateTime? from,
    DateTime? to,
    int? page,
    int? perPage,
  }) {
    return _uri(
      'records/metrics',
      query: _recordsMetricsQuery(
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

  // ─────────────────────────────────────────────
  // Documents
  // ─────────────────────────────────────────────

  Uri recordsDocumentsList({
    String? search,
    String? profileId,
    String? claimPackId,
    String? documentType,
    String? membershipId,
    String? payerContactId,
    String? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    return _uri(
      'records/documents',
      query: _recordsQuery(
        search: search,
        isActive: isActive,
        perPage: perPage,
        page: page,
        extras: {
          'profile_id': profileId,
          'claim_pack_id': claimPackId,
          'document_type': documentType,
          'membership_id': membershipId,
          'payer_contact_id': payerContactId,
          'status': status,
        },
      ),
    );
  }

  Uri recordsDocumentsListForProfile({
    required String profileId,
    String? search,
    String? claimPackId,
    String? documentType,
    String? membershipId,
    String? payerContactId,
    String? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    return _uri(
      'records/profiles/${_seg(profileId)}/documents',
      query: _recordsQuery(
        search: search,
        isActive: isActive,
        perPage: perPage,
        page: page,
        extras: {
          'claim_pack_id': claimPackId,
          'document_type': documentType,
          'membership_id': membershipId,
          'payer_contact_id': payerContactId,
          'status': status,
        },
      ),
    );
  }

  Uri recordsDocumentGet({
    required String profileId,
    required String documentId,
  }) => _uri(
    'records/profiles/${_seg(profileId)}/documents/'
    '${_seg(documentId)}',
  );

  Uri recordsDocumentCreate({required String profileId}) =>
      _uri('records/profiles/${_seg(profileId)}/documents');

  Uri recordsDocumentUpdate({
    required String profileId,
    required String documentId,
  }) => _uri(
    'records/profiles/${_seg(profileId)}/documents/'
    '${_seg(documentId)}',
  );

  Uri recordsDocumentDelete({
    required String profileId,
    required String documentId,
  }) => _uri(
    'records/profiles/${_seg(profileId)}/documents/'
    '${_seg(documentId)}',
  );

  // ─────────────────────────────────────────────
  // Shared Query Helpers
  // ─────────────────────────────────────────────

  Map<String, String> _recordsQuery({
    String? search,
    bool? isActive,
    int? perPage,
    int? page,
    Map<String, String?> extras = const {},
  }) {
    final query = <String, String>{};

    void add(String key, String? value) {
      final cleaned = value?.trim();

      if (cleaned != null && cleaned.isNotEmpty) {
        query[key] = cleaned;
      }
    }

    add('search', search);

    for (final entry in extras.entries) {
      add(entry.key, entry.value);
    }

    if (isActive != null) {
      query['is_active'] = isActive.toString();
    }

    if (perPage != null && perPage > 0) {
      query['per_page'] = perPage.toString();
    }

    if (page != null && page > 0) {
      query['page'] = page.toString();
    }

    return query;
  }

  Map<String, String>? _recordsMetricsQuery({
    String? profileId,
    String? type,
    bool? isActive,
    DateTime? from,
    DateTime? to,
    int? page,
    int? perPage,
  }) {
    final query = _recordsQuery(
      isActive: isActive,
      perPage: perPage,
      page: page,
      extras: {'profile_id': profileId, 'type': type},
    );

    if (from != null) {
      query['from'] = from.toUtc().toIso8601String();
    }

    if (to != null) {
      query['to'] = to.toUtc().toIso8601String();
    }

    return query.isEmpty ? null : query;
  }
}
