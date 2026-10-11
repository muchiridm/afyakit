part of 'routes.dart';

/// Shared application records, independent of the Retail feature flag.

///

/// All requests remain tenant-scoped through [AfyaKitRoutes._uri].

/// App selection/authorisation is performed by the API client and backend,

/// not by accepting an arbitrary appId query parameter.

extension AfyaKitRecordsRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  // Native Contacts pilot (Firestore, no Zoho required)
  // ─────────────────────────────────────────────

  Uri recordsNativeContactsList({int page = 1, int perPage = 50}) => _uri(
    'records/native-contacts',
    query: _recordsQuery(page: page, perPage: perPage),
  );

  Uri recordsNativeContactCreate() => _uri('records/native-contacts');

  Uri recordsNativeContactGet(String id) =>
      _uri('records/native-contacts/${_seg(id)}');

  Uri recordsNativeContactUpdate(String id) =>
      _uri('records/native-contacts/${_seg(id)}');

  /// Remove app membership, never delete the canonical contact.
  Uri recordsNativeContactRemoveFromApp(String id) =>
      _uri('records/native-contacts/${_seg(id)}/membership');

  Uri recordsNativeContactAllocateAccountNumber(String contactId) =>
      _uri('records/native-contacts/${_seg(contactId)}/account-number');

  // Legacy Zoho-backed Contacts (existing DawaPap workflow)

  // ─────────────────────────────────────────────

  Uri recordsContactsList({
    String? search,

    String? type,

    int perPage = 50,

    int page = 1,

    String? accountNumber,
  }) {
    final query = _recordsQuery(
      search: search,

      perPage: perPage,

      page: page,

      extras: {'type': type},

      searchKey: 'search_text',
    );

    _addContactAccountScope(query, accountNumber);

    return _uri('records/contacts', query: query);
  }

  Uri recordsCustomersList({
    String? search,

    int perPage = 50,

    int page = 1,

    String? accountNumber,
  }) {
    final query = _recordsQuery(
      search: search,

      perPage: perPage,

      page: page,

      searchKey: 'search_text',
    );

    _addContactAccountScope(query, accountNumber);

    return _uri('records/contacts/customers', query: query);
  }

  Uri recordsContactGet(String contactId) =>
      _uri('records/contacts/${_seg(contactId)}');

  Uri recordsContactCreate() => _uri('records/contacts');

  Uri recordsContactUpdate(String contactId) =>
      _uri('records/contacts/${_seg(contactId)}');

  /// Shared-Zoho deletion is normally forbidden; use membership removal.

  @Deprecated('Use recordsContactMembershipRemove instead.')
  Uri recordsContactDelete(String contactId) =>
      _uri('records/contacts/${_seg(contactId)}');

  /// Enrol an existing Zoho contact in the current app (POST).

  Uri recordsContactMembershipAdd(String contactId) =>
      _uri('records/contacts/${_seg(contactId)}/membership');

  /// Remove only the current app's enrolment (DELETE), not the Zoho contact.

  Uri recordsContactMembershipRemove(String contactId) =>
      _uri('records/contacts/${_seg(contactId)}/membership');

  // ─────────────────────────────────────────────

  // Health profiles

  // ─────────────────────────────────────────────

  Uri recordsProfilesList({
    String? search,

    String? contactId,

    String? relationship,

    bool? isActive,

    int perPage = 50,

    int page = 1,
  }) => _uri(
    'records/profiles',

    query: _recordsQuery(
      search: search,

      isActive: isActive,

      perPage: perPage,

      page: page,

      extras: {'contact_id': contactId, 'relationship': relationship},
    ),
  );

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

  // Profile link requests

  // ─────────────────────────────────────────────

  Uri recordsProfileLinkRequestCreate(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}/link-requests');

  Uri recordsProfileLinkRequestsList({
    String? status,

    String? profileId,

    int perPage = 50,

    int page = 1,
  }) => _uri(
    'records/profiles/link-requests',

    query: _recordsQuery(
      perPage: perPage,

      page: page,

      extras: {'status': status, 'profile_id': profileId},
    ),
  );

  Uri recordsProfileLinkRequestApprove(String requestId) =>
      _uri('records/profiles/link-requests/${_seg(requestId)}/approve');

  Uri recordsProfileLinkRequestReject(String requestId) =>
      _uri('records/profiles/link-requests/${_seg(requestId)}/reject');

  // ─────────────────────────────────────────────

  // Profile-linked contacts

  // ─────────────────────────────────────────────

  Uri recordsProfileLinkedContactCreate(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}/linked-contacts');

  Uri recordsProfileLinkedContactDelete({
    required String profileId,

    required String contactId,
  }) => _uri(
    'records/profiles/${_seg(profileId)}/linked-contacts/${_seg(contactId)}',
  );

  // ─────────────────────────────────────────────

  // Health metrics

  // ─────────────────────────────────────────────

  Uri recordsProfileHealthMetricsList(
    String profileId, {

    String? type,

    bool? isActive,

    DateTime? from,

    DateTime? to,

    int? page,

    int? perPage,
  }) => _uri(
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

  Uri recordsProfileHealthMetricGet({
    required String profileId,

    required String metricId,
  }) => _uri('records/profiles/${_seg(profileId)}/metrics/${_seg(metricId)}');

  Uri recordsProfileHealthMetricCreate(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}/metrics');

  Uri recordsProfileHealthMetricUpdate({
    required String profileId,

    required String metricId,
  }) => _uri('records/profiles/${_seg(profileId)}/metrics/${_seg(metricId)}');

  Uri recordsProfileHealthMetricDelete({
    required String profileId,

    required String metricId,
  }) => _uri('records/profiles/${_seg(profileId)}/metrics/${_seg(metricId)}');

  Uri recordsHealthMetricsList({
    String? profileId,

    String? type,

    bool? isActive,

    DateTime? from,

    DateTime? to,

    int? page,

    int? perPage,
  }) => _uri(
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
  }) => _uri(
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
  }) => _uri(
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

  Uri recordsDocumentGet({
    required String profileId,

    required String documentId,
  }) =>
      _uri('records/profiles/${_seg(profileId)}/documents/${_seg(documentId)}');

  Uri recordsDocumentCreate({required String profileId}) =>
      _uri('records/profiles/${_seg(profileId)}/documents');

  Uri recordsDocumentUpdate({
    required String profileId,

    required String documentId,
  }) =>
      _uri('records/profiles/${_seg(profileId)}/documents/${_seg(documentId)}');

  Uri recordsDocumentDelete({
    required String profileId,

    required String documentId,
  }) =>
      _uri('records/profiles/${_seg(profileId)}/documents/${_seg(documentId)}');

  // ─────────────────────────────────────────────

  // Shared query helpers

  // ─────────────────────────────────────────────

  Map<String, String> _recordsQuery({
    String? search,

    String searchKey = 'search',

    bool? isActive,

    int? perPage,

    int? page,

    Map<String, String?> extras = const {},
  }) {
    final query = <String, String>{};

    void add(String key, String? value) {
      final cleaned = value?.trim();

      if (cleaned != null && cleaned.isNotEmpty) query[key] = cleaned;
    }

    add(searchKey, search);

    for (final entry in extras.entries) {
      add(entry.key, entry.value);
    }

    if (isActive != null) query['is_active'] = isActive.toString();

    if (perPage != null && perPage > 0) query['per_page'] = '$perPage';

    if (page != null && page > 0) query['page'] = '$page';

    return query;
  }

  void _addContactAccountScope(
    Map<String, String> query,

    String? accountNumber,
  ) {
    final account = (accountNumber ?? '').trim();

    if (account.isEmpty) return;

    query['scope'] = 'account';

    query['account_number'] = account;
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

    if (from != null) query['from'] = from.toUtc().toIso8601String();

    if (to != null) query['to'] = to.toUtc().toIso8601String();

    return query.isEmpty ? null : query;
  }
}
