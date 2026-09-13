part of 'routes.dart';

extension AfyaKitInsuranceRoutes on AfyaKitRoutes {
  Uri insuranceMembershipsList({
    String? search,
    String? profileId,
    String? patientNo,
    String? payerContactId,
    String? memberNo,
    String? scheme,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) query[key] = v;
    }

    add('search', search);
    add('profile_id', profileId);
    add('patient_no', patientNo);
    add('payer_contact_id', payerContactId);
    add('member_no', memberNo);
    add('scheme', scheme);

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('insurance/memberships', query: query);
  }

  Uri insuranceMembershipGet(String membershipId) =>
      _uri('insurance/memberships/${_seg(membershipId)}');

  Uri insuranceMembershipCreate() => _uri('insurance/memberships');

  Uri insuranceMembershipUpdate(String membershipId) =>
      _uri('insurance/memberships/${_seg(membershipId)}');

  Uri insuranceMembershipDelete(String membershipId) =>
      _uri('insurance/memberships/${_seg(membershipId)}');

  Uri insuranceClaimPacksList({
    String? search,
    String? membershipId,
    String? profileId,
    String? payerContactId,
    String? invoiceId,
    String? memberNo,
    String? authCode,
    String? insurerClaimNo,
    String? visitNo,
    String? prescriptionId,
    String? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) query[key] = v;
    }

    add('search', search);
    add('membership_id', membershipId);
    add('profile_id', profileId);
    add('payer_contact_id', payerContactId);
    add('invoice_id', invoiceId);
    add('member_no', memberNo);
    add('auth_code', authCode);
    add('insurer_claim_no', insurerClaimNo);
    add('visit_no', visitNo);
    add('prescription_id', prescriptionId);
    add('status', status);

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('insurance/claim-packs', query: query);
  }

  Uri insuranceClaimPacksListForProfile({
    required String profileId,
    String? search,
    String? membershipId,
    String? payerContactId,
    String? invoiceId,
    String? memberNo,
    String? authCode,
    String? insurerClaimNo,
    String? visitNo,
    String? prescriptionId,
    String? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) query[key] = v;
    }

    add('search', search);
    add('membership_id', membershipId);
    add('payer_contact_id', payerContactId);
    add('invoice_id', invoiceId);
    add('member_no', memberNo);
    add('auth_code', authCode);
    add('insurer_claim_no', insurerClaimNo);
    add('visit_no', visitNo);
    add('prescription_id', prescriptionId);
    add('status', status);

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri(
      'insurance/profiles/${_seg(profileId)}/claim-packs',
      query: query,
    );
  }

  Uri insuranceClaimPackGet({
    required String profileId,
    required String claimPackId,
  }) {
    return _uri(
      'insurance/profiles/${_seg(profileId)}/claim-packs/${_seg(claimPackId)}',
    );
  }

  Uri insuranceClaimPackCreate({required String profileId}) {
    return _uri('insurance/profiles/${_seg(profileId)}/claim-packs');
  }

  Uri insuranceClaimPackUpdate({
    required String profileId,
    required String claimPackId,
  }) {
    return _uri(
      'insurance/profiles/${_seg(profileId)}/claim-packs/${_seg(claimPackId)}',
    );
  }

  Uri insuranceClaimPackDelete({
    required String profileId,
    required String claimPackId,
  }) {
    return _uri(
      'insurance/profiles/${_seg(profileId)}/claim-packs/${_seg(claimPackId)}',
    );
  }

  Uri insuranceDocumentsList({
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
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) query[key] = v;
    }

    add('search', search);
    add('profile_id', profileId);
    add('claim_pack_id', claimPackId);
    add('document_type', documentType);
    add('membership_id', membershipId);
    add('payer_contact_id', payerContactId);
    add('status', status);

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('insurance/documents', query: query);
  }

  Uri insuranceDocumentsListForProfile({
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
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) query[key] = v;
    }

    add('search', search);
    add('claim_pack_id', claimPackId);
    add('document_type', documentType);
    add('membership_id', membershipId);
    add('payer_contact_id', payerContactId);
    add('status', status);

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri(
      'insurance/profiles/${_seg(profileId)}/documents',
      query: query,
    );
  }

  Uri insuranceDocumentGet({
    required String profileId,
    required String documentId,
  }) {
    return _uri(
      'insurance/profiles/${_seg(profileId)}/documents/${_seg(documentId)}',
    );
  }

  Uri insuranceDocumentCreate({required String profileId}) {
    return _uri('insurance/profiles/${_seg(profileId)}/documents');
  }

  Uri insuranceDocumentUpdate({
    required String profileId,
    required String documentId,
  }) {
    return _uri(
      'insurance/profiles/${_seg(profileId)}/documents/${_seg(documentId)}',
    );
  }

  Uri insuranceDocumentDelete({
    required String profileId,
    required String documentId,
  }) {
    return _uri(
      'insurance/profiles/${_seg(profileId)}/documents/${_seg(documentId)}',
    );
  }
}
