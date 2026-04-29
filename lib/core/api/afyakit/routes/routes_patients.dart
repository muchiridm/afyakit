// lib/core/api/afyakit/routes/routes_patients.dart

part of 'routes.dart';

extension AfyaKitPatientRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🧑‍⚕️ Patients (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  /// List patient profiles.
  ///
  /// Backend:
  /// GET /patients
  ///
  /// Supported filters:
  /// - search / q
  /// - payer_contact_id
  /// - insurance
  /// - scheme
  /// - is_active
  /// - per_page / page
  Uri patientsList({
    String? search,
    String? payerContactId,
    String? insurance,
    String? scheme,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final s = (search ?? '').trim();
    if (s.isNotEmpty) query['search'] = s;

    final payer = (payerContactId ?? '').trim();
    if (payer.isNotEmpty) query['payer_contact_id'] = payer;

    final ins = (insurance ?? '').trim();
    if (ins.isNotEmpty) query['insurance'] = ins;

    final sch = (scheme ?? '').trim();
    if (sch.isNotEmpty) query['scheme'] = sch;

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('patients', query: query);
  }

  /// GET /patients/:patientId
  Uri patientGet(String patientId) => _uri('patients/${_seg(patientId)}');

  /// POST /patients
  Uri patientCreate() => _uri('patients');

  /// PUT /patients/:patientId
  Uri patientUpdate(String patientId) => _uri('patients/${_seg(patientId)}');

  /// DELETE /patients/:patientId
  Uri patientDelete(String patientId) => _uri('patients/${_seg(patientId)}');
}
