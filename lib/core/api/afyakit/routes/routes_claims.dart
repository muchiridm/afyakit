// lib/core/api/afyakit/routes/routes_claims.dart

part of 'routes.dart';

extension AfyaKitClaimsRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🧾 Claims / Insurance
  // ─────────────────────────────────────────────

  /// GET /claims/insurance
  Uri claimsInsuranceList({
    String? search,
    String? patientId,
    String? payerContactId,
    String? invoiceId,
    String? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final s = (search ?? '').trim();
    if (s.isNotEmpty) query['search'] = s;

    final pid = (patientId ?? '').trim();
    if (pid.isNotEmpty) query['patient_id'] = pid;

    final payer = (payerContactId ?? '').trim();
    if (payer.isNotEmpty) query['payer_contact_id'] = payer;

    final inv = (invoiceId ?? '').trim();
    if (inv.isNotEmpty) query['invoice_id'] = inv;

    final st = (status ?? '').trim();
    if (st.isNotEmpty) query['status'] = st;

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('claims/insurance', query: query);
  }

  /// GET /claims/insurance/:claimId
  Uri claimsInsuranceGet(String claimId) =>
      _uri('claims/insurance/${_seg(claimId)}');

  /// POST /claims/insurance
  Uri claimsInsuranceCreate() => _uri('claims/insurance');

  /// PUT /claims/insurance/:claimId
  Uri claimsInsuranceUpdate(String claimId) =>
      _uri('claims/insurance/${_seg(claimId)}');

  /// DELETE /claims/insurance/:claimId
  Uri claimsInsuranceDelete(String claimId) =>
      _uri('claims/insurance/${_seg(claimId)}');
}
