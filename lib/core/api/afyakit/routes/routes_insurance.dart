part of 'routes.dart';

extension AfyaKitInsuranceRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🛡️ Insurance / Memberships
  // ─────────────────────────────────────────────

  /// GET /insurance/memberships
  Uri insuranceMembershipsList({
    String? search,
    String? patientId,
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
    add('patient_id', patientId);
    add('patient_no', patientNo);
    add('payer_contact_id', payerContactId);
    add('member_no', memberNo);
    add('scheme', scheme);

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('insurance/memberships', query: query);
  }

  /// GET /insurance/memberships/:membershipId
  Uri insuranceMembershipGet(String membershipId) =>
      _uri('insurance/memberships/${_seg(membershipId)}');

  /// POST /insurance/memberships
  Uri insuranceMembershipCreate() => _uri('insurance/memberships');

  /// PUT /insurance/memberships/:membershipId
  Uri insuranceMembershipUpdate(String membershipId) =>
      _uri('insurance/memberships/${_seg(membershipId)}');

  /// DELETE /insurance/memberships/:membershipId
  Uri insuranceMembershipDelete(String membershipId) =>
      _uri('insurance/memberships/${_seg(membershipId)}');

  // ─────────────────────────────────────────────
  // 🧾 Insurance / Claim Packs
  // ─────────────────────────────────────────────

  /// GET /insurance/claim-packs
  ///
  /// Staff global list only.
  Uri insuranceClaimPacksList({
    String? search,
    String? membershipId,
    String? patientId,
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
    add('patient_id', patientId);
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

  /// GET /insurance/patients/:patientId/claim-packs
  ///
  /// Staff or member patient-scoped list.
  Uri insuranceClaimPacksListForPatient({
    required String patientId,
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
      'insurance/patients/${_seg(patientId)}/claim-packs',
      query: query,
    );
  }

  /// GET /insurance/patients/:patientId/claim-packs/:claimPackId
  Uri insuranceClaimPackGet({
    required String patientId,
    required String claimPackId,
  }) {
    return _uri(
      'insurance/patients/${_seg(patientId)}/claim-packs/${_seg(claimPackId)}',
    );
  }

  /// POST /insurance/patients/:patientId/claim-packs
  Uri insuranceClaimPackCreate({required String patientId}) {
    return _uri('insurance/patients/${_seg(patientId)}/claim-packs');
  }

  /// PUT /insurance/patients/:patientId/claim-packs/:claimPackId
  Uri insuranceClaimPackUpdate({
    required String patientId,
    required String claimPackId,
  }) {
    return _uri(
      'insurance/patients/${_seg(patientId)}/claim-packs/${_seg(claimPackId)}',
    );
  }

  /// DELETE /insurance/patients/:patientId/claim-packs/:claimPackId
  Uri insuranceClaimPackDelete({
    required String patientId,
    required String claimPackId,
  }) {
    return _uri(
      'insurance/patients/${_seg(patientId)}/claim-packs/${_seg(claimPackId)}',
    );
  }

  // ─────────────────────────────────────────────
  // 📎 Insurance / Documents
  // ─────────────────────────────────────────────

  /// GET /insurance/documents
  ///
  /// Staff global list only.
  Uri insuranceDocumentsList({
    String? search,
    String? patientId,
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
    add('patient_id', patientId);
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

  /// GET /insurance/patients/:patientId/documents
  ///
  /// Staff or member patient-scoped list.
  Uri insuranceDocumentsListForPatient({
    required String patientId,
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
      'insurance/patients/${_seg(patientId)}/documents',
      query: query,
    );
  }

  /// GET /insurance/patients/:patientId/documents/:documentId
  Uri insuranceDocumentGet({
    required String patientId,
    required String documentId,
  }) {
    return _uri(
      'insurance/patients/${_seg(patientId)}/documents/${_seg(documentId)}',
    );
  }

  /// POST /insurance/patients/:patientId/documents
  Uri insuranceDocumentCreate({required String patientId}) {
    return _uri('insurance/patients/${_seg(patientId)}/documents');
  }

  /// PUT /insurance/patients/:patientId/documents/:documentId
  Uri insuranceDocumentUpdate({
    required String patientId,
    required String documentId,
  }) {
    return _uri(
      'insurance/patients/${_seg(patientId)}/documents/${_seg(documentId)}',
    );
  }

  /// DELETE /insurance/patients/:patientId/documents/:documentId
  Uri insuranceDocumentDelete({
    required String patientId,
    required String documentId,
  }) {
    return _uri(
      'insurance/patients/${_seg(patientId)}/documents/${_seg(documentId)}',
    );
  }
}
