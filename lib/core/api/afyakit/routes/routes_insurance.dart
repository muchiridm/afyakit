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
    String? memberNumber,
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
    add('member_number', memberNumber);
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
    String? memberNumber,
    String? scheme,
    String? authorizationNumber,
    String? claimNumber,
    String? visitNumber,
    String? prescriptionNumber,
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
    add('member_number', memberNumber);
    add('scheme', scheme);
    add('authorization_number', authorizationNumber);
    add('claim_number', claimNumber);
    add('visit_number', visitNumber);
    add('prescription_number', prescriptionNumber);
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
  // Backward-compatible aliases during refactor
  // ─────────────────────────────────────────────
  //
  // These keep older FE services compiling while you migrate from:
  // claimsInsuranceX(...)
  // to:
  // insuranceClaimX(...)
  //
  // Delete these aliases once all callers are updated.

  @Deprecated('Use insuranceClaimsList instead.')
  Uri claimsInsuranceList({
    String? search,
    String? membershipId,
    String? patientId,
    String? patientNo,
    String? payerContactId,
    String? invoiceId,
    String? memberNumber,
    String? scheme,
    String? authorizationNumber,
    String? claimNumber,
    String? visitNumber,
    String? prescriptionNumber,
    String? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    return insuranceClaimsList(
      search: search,
      membershipId: membershipId,
      patientId: patientId,
      patientNo: patientNo,
      payerContactId: payerContactId,
      invoiceId: invoiceId,
      memberNumber: memberNumber,
      scheme: scheme,
      authorizationNumber: authorizationNumber,
      claimNumber: claimNumber,
      visitNumber: visitNumber,
      prescriptionNumber: prescriptionNumber,
      status: status,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );
  }

  @Deprecated('Use insuranceClaimGet instead.')
  Uri claimsInsuranceGet(String claimId) => insuranceClaimGet(claimId);

  @Deprecated('Use insuranceClaimCreate instead.')
  Uri claimsInsuranceCreate() => insuranceClaimCreate();

  @Deprecated('Use insuranceClaimUpdate instead.')
  Uri claimsInsuranceUpdate(String claimId) => insuranceClaimUpdate(claimId);

  @Deprecated('Use insuranceClaimDelete instead.')
  Uri claimsInsuranceDelete(String claimId) => insuranceClaimDelete(claimId);
}
