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

  /// Read-only; platform superadmin required by backend.
  Uri recordsProfileDependencies(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}/dependencies');

  /// POST: superadmin-only permanent purge, with explicit retention review.
  Uri recordsProfilePurge(String profileId) =>
      _uri('records/profiles/${_seg(profileId)}/purge');

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
  // Health metrics — tenant-level independent records
  // ---------------------------------------------------------

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

  Uri recordsHealthMetricCreate() => _uri('records/metrics');
  Uri recordsHealthMetricGet(String metricId) =>
      _uri('records/metrics/${_seg(metricId)}');
  Uri recordsHealthMetricUpdate(String metricId) =>
      recordsHealthMetricGet(metricId);
  Uri recordsHealthMetricDelete(String metricId) =>
      recordsHealthMetricGet(metricId);

  // Existing Dart callers may still pass profileId; it is now a query/body field,
  // NEVER a resource path component. Callers creating records must send profile_id.
  Uri recordsProfileHealthMetricsList(
    String profileId, {
    String? type,
    bool? isActive,
    DateTime? from,
    DateTime? to,
    int? page,
    int? perPage,
  }) => recordsHealthMetricsList(
    profileId: profileId,
    type: type,
    isActive: isActive,
    from: from,
    to: to,
    page: page,
    perPage: perPage,
  );
  Uri recordsProfileHealthMetricGet({
    required String profileId,
    required String metricId,
  }) => recordsHealthMetricGet(metricId);
  Uri recordsProfileHealthMetricCreate(String profileId) =>
      recordsHealthMetricCreate();
  Uri recordsProfileHealthMetricUpdate({
    required String profileId,
    required String metricId,
  }) => recordsHealthMetricUpdate(metricId);
  Uri recordsProfileHealthMetricDelete({
    required String profileId,
    required String metricId,
  }) => recordsHealthMetricDelete(metricId);

  // ---------------------------------------------------------
  // Documents — tenant-level independent records
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

  Uri recordsDocumentCreateCanonical() => _uri('records/documents');
  Uri recordsDocumentById(String documentId) =>
      _uri('records/documents/${_seg(documentId)}');
  Uri recordsDocumentStorageAccess() =>
      _uri('records/documents/storage-access');

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
  }) => recordsDocumentsList(
    search: search,
    profileId: profileId,
    claimPackId: claimPackId,
    documentType: documentType,
    membershipId: membershipId,
    payerContactId: payerContactId,
    status: status,
    isActive: isActive,
    perPage: perPage,
    page: page,
  );
  Uri recordsDocumentGet({
    required String profileId,
    required String documentId,
  }) => recordsDocumentById(documentId);
  Uri recordsDocumentCreate({required String profileId}) =>
      recordsDocumentCreateCanonical();
  Uri recordsDocumentUpdate({
    required String profileId,
    required String documentId,
  }) => recordsDocumentById(documentId);
  Uri recordsDocumentDelete({
    required String profileId,
    required String documentId,
  }) => recordsDocumentById(documentId);

  // ---------------------------------------------------------
  // Delivery addresses — staff and member
  // ---------------------------------------------------------

  /// Staff: list by account_number (canonical Native Contact ID).
  Uri recordsDeliveryAddressesList(
    String contactId, {
    bool includeArchived = false,
  }) => _uri(
    'records/delivery-addresses',
    query: {
      'account_number': contactId,
      if (includeArchived) 'include_archived': 'true',
    },
  );

  /// POST body must contain account_number; it is not part of the URL.
  Uri recordsDeliveryAddressCreate(String contactId) =>
      _uri('records/delivery-addresses');
  Uri recordsDeliveryAddressGet(String contactId, String addressId) =>
      _uri('records/delivery-addresses/${_seg(addressId)}');
  Uri recordsDeliveryAddressUpdate(String contactId, String addressId) =>
      recordsDeliveryAddressGet(contactId, addressId);
  Uri recordsDeliveryAddressArchive(String contactId, String addressId) =>
      recordsDeliveryAddressGet(contactId, addressId);

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
