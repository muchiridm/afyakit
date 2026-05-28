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
  Uri insuranceClaimsList({
    String? search,
    String? membershipId,
    String? patientId,
    String? patientNo,
    String? payerContactId,
    String? invoiceId,
    String? memberNo,
    String? scheme,
    String? authCode,
    String? claimNo,
    String? visitNo,
    String? prescriptionNo,
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
    add('patient_no', patientNo);
    add('payer_contact_id', payerContactId);
    add('invoice_id', invoiceId);
    add('member_no', memberNo);
    add('scheme', scheme);
    add('auth_code', authCode);
    add('claim_no', claimNo);
    add('visit_no', visitNo);
    add('prescription_no', prescriptionNo);
    add('prescription_id', prescriptionId);
    add('status', status);

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('insurance/claims', query: query);
  }

  /// GET /insurance/claims/:claimId
  Uri insuranceClaimGet(String claimId) =>
      _uri('insurance/claims/${_seg(claimId)}');

  /// POST /insurance/claims
  Uri insuranceClaimCreate() => _uri('insurance/claims');

  /// PUT /insurance/claims/:claimId
  Uri insuranceClaimUpdate(String claimId) =>
      _uri('insurance/claims/${_seg(claimId)}');

  /// DELETE /insurance/claims/:claimId
  Uri insuranceClaimDelete(String claimId) =>
      _uri('insurance/claims/${_seg(claimId)}');

  // ─────────────────────────────────────────────
  // 📎 Insurance / Claim Pack
  // ─────────────────────────────────────────────

  /// PUT /insurance/claims/:claimId/claim-form
  Uri insuranceClaimAttachClaimForm(String claimId) =>
      _uri('insurance/claims/${_seg(claimId)}/claim-form');

  /// DELETE /insurance/claims/:claimId/claim-form
  Uri insuranceClaimDetachClaimForm(String claimId) =>
      _uri('insurance/claims/${_seg(claimId)}/claim-form');

  /// PUT /insurance/claims/:claimId/prescription
  Uri insuranceClaimAttachPrescription(String claimId) =>
      _uri('insurance/claims/${_seg(claimId)}/prescription');

  /// DELETE /insurance/claims/:claimId/prescription
  Uri insuranceClaimDetachPrescription(String claimId) =>
      _uri('insurance/claims/${_seg(claimId)}/prescription');
}
