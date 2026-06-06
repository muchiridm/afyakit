// lib/core/api/afyakit/routes/routes_insurance.dart

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
  // 🧾 Insurance / Claims
  // ─────────────────────────────────────────────

  /// GET /insurance/claims
  ///
  /// Staff global list only.
  Uri insuranceClaimsList({
    String? search,
    String? membershipId,
    String? patientId,
    String? payerContactId,
    String? invoiceId,
    String? memberNo,
    String? authCode,
    String? claimNo,
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
    add('claim_no', claimNo);
    add('visit_no', visitNo);
    add('prescription_id', prescriptionId);
    add('status', status);

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('insurance/claims', query: query);
  }

  /// GET /insurance/patients/:patientId/claims
  ///
  /// Staff or member patient-scoped list.
  Uri insuranceClaimsListForPatient({
    required String patientId,
    String? search,
    String? membershipId,
    String? payerContactId,
    String? invoiceId,
    String? memberNo,
    String? authCode,
    String? claimNo,
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
    add('claim_no', claimNo);
    add('visit_no', visitNo);
    add('prescription_id', prescriptionId);
    add('status', status);

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('insurance/patients/${_seg(patientId)}/claims', query: query);
  }

  /// GET /insurance/patients/:patientId/claims/:claimId
  Uri insuranceClaimGet({required String patientId, required String claimId}) =>
      _uri('insurance/patients/${_seg(patientId)}/claims/${_seg(claimId)}');

  /// POST /insurance/patients/:patientId/claims
  Uri insuranceClaimCreate({required String patientId}) =>
      _uri('insurance/patients/${_seg(patientId)}/claims');

  /// PUT /insurance/patients/:patientId/claims/:claimId
  Uri insuranceClaimUpdate({
    required String patientId,
    required String claimId,
  }) => _uri('insurance/patients/${_seg(patientId)}/claims/${_seg(claimId)}');

  /// DELETE /insurance/patients/:patientId/claims/:claimId
  Uri insuranceClaimDelete({
    required String patientId,
    required String claimId,
  }) => _uri('insurance/patients/${_seg(patientId)}/claims/${_seg(claimId)}');
}
