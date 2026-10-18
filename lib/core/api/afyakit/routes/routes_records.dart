part of 'routes.dart';

/// Shared tenant-scoped records routes.
/// App scope is resolved by the API.
extension AfyaKitRecordsRoutes on AfyaKitRoutes {
  // ---------------------------------------------------------
  // Native Contacts
  // ---------------------------------------------------------

  Uri recordsContactsList({int page = 1, int perPage = 50}) => _uri(
    'records/contacts',
    query: _recordsQuery(page: page, perPage: perPage),
  );

  Uri recordsContactCreate() => _uri('records/contacts');

  Uri recordsMyContact() => _uri('records/contacts/me');

  /// Member-only linked profile summaries; account is resolved server-side.
  /// GET /v1/records/contacts/me/health-profiles
  Uri recordsMyContactHealthProfilesList({int page = 1, int perPage = 50}) =>
      _uri(
        'records/contacts/me/health-profiles',
        query: _recordsQuery(page: page, perPage: perPage),
      );

  /// Canonical Native Contact identifier: AC-XXXXXX.
  ///
  Uri recordsContactGet(String accountNumber) =>
      _uri('records/contacts/${_seg(accountNumber)}');

  Uri recordsContactUpdate(String accountNumber) =>
      recordsContactGet(accountNumber);

  Uri recordsContactMembershipRemove(String accountNumber) =>
      _uri('records/contacts/${_seg(accountNumber)}/membership');

  /// Staff-authorised linked Health Profile summaries for a Native Contact.
  ///
  /// GET /v1/records/contacts/:accountNumber/health-profiles
  ///
  /// The backend resolves active relationships from health_profile_links.
  Uri recordsContactHealthProfilesList(
    String accountNumber, {
    int page = 1,
    int perPage = 50,
  }) => _uri(
    'records/contacts/${_seg(accountNumber)}/health-profiles',
    query: _recordsQuery(page: page, perPage: perPage),
  );

  /// Staff: create an association between a canonical Contact and Profile.
  Uri recordsContactHealthProfileLinkCreate(String accountNumber) =>
      _uri('records/contacts/${_seg(accountNumber)}/health-profiles');

  /// Staff: change an existing association's relationship (or reactivate it).
  Uri recordsContactHealthProfileLinkUpdate({
    required String accountNumber,
    required String profileId,
  }) => _uri(
    'records/contacts/${_seg(accountNumber)}/health-profiles/${_seg(profileId)}',
  );

  /// Staff: deactivate an association, preserving both records.
  Uri recordsContactHealthProfileLinkDelete({
    required String accountNumber,
    required String profileId,
  }) => recordsContactHealthProfileLinkUpdate(
    accountNumber: accountNumber,
    profileId: profileId,
  );

  // ---------------------------------------------------------
  // Health profiles
  // ---------------------------------------------------------

  Uri recordsProfilesList({
    String? search,
    String? accountNumber,
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
      extras: {'account_number': accountNumber, 'relationship': relationship},
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

  // ---------------------------------------------------------
  // Profile link requests
  // ---------------------------------------------------------

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

  // ---------------------------------------------------------
  // Profile-linked Native Contacts
  // ---------------------------------------------------------

  Uri recordsProfileLinkedContactCreate(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}/linked-contacts');

  /// The path parameter is a canonical Native Contact account number.
  Uri recordsProfileLinkedContactDelete({
    required String profileId,
    required String accountNumber,
  }) => _uri(
    'records/profiles/${_seg(profileId)}/linked-contacts/${_seg(accountNumber)}',
  );

  Uri recordsProfileLinkedContactsList(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}/linked-contacts');

  Uri recordsProfileRelationshipsList(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}/relationships');

  // ---------------------------------------------------------
  // Health metrics
  // ---------------------------------------------------------

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

  // ---------------------------------------------------------
  // Documents
  // ---------------------------------------------------------

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

  // ---------------------------------------------------------
  // Delivery addresses — staff-managed contacts
  // ---------------------------------------------------------

  Uri recordsDeliveryAddressesList(
    String contactId, {
    bool includeArchived = false,
  }) => _uri(
    'records/delivery-addresses/contacts/${_seg(contactId)}',
    query: includeArchived ? {'include_archived': 'true'} : null,
  );

  Uri recordsDeliveryAddressCreate(String contactId) =>
      _uri('records/delivery-addresses/contacts/${_seg(contactId)}');

  Uri recordsDeliveryAddressGet(String contactId, String addressId) => _uri(
    'records/delivery-addresses/contacts/'
    '${_seg(contactId)}/${_seg(addressId)}',
  );

  Uri recordsDeliveryAddressUpdate(String contactId, String addressId) =>
      recordsDeliveryAddressGet(contactId, addressId);

  Uri recordsDeliveryAddressArchive(String contactId, String addressId) =>
      recordsDeliveryAddressGet(contactId, addressId);

  // ---------------------------------------------------------
  // Delivery addresses — member-owned
  // ---------------------------------------------------------

  Uri recordsMyDeliveryAddressesList({bool includeArchived = false}) => _uri(
    'records/delivery-addresses/me',
    query: includeArchived ? {'include_archived': 'true'} : null,
  );

  Uri recordsMyDeliveryAddressCreate() => _uri('records/delivery-addresses/me');

  Uri recordsMyDeliveryAddressGet(String addressId) =>
      _uri('records/delivery-addresses/me/${_seg(addressId)}');

  Uri recordsMyDeliveryAddressUpdate(String addressId) =>
      recordsMyDeliveryAddressGet(addressId);

  Uri recordsMyDeliveryAddressArchive(String addressId) =>
      recordsMyDeliveryAddressGet(addressId);

  // ---------------------------------------------------------
  // Shared query helpers
  // ---------------------------------------------------------

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
      query['per_page'] = '$perPage';
    }

    if (page != null && page > 0) {
      query['page'] = '$page';
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
