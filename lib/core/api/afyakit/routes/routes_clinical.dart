part of 'routes.dart';

extension AfyaKitClinicalRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🧑‍⚕️ Clinical / Patients
  // ─────────────────────────────────────────────

  Uri clinicalPatientsList({
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

    return _uri('clinical/patients', query: query);
  }

  Uri clinicalPatientGet(String patientId) =>
      _uri('clinical/patients/${_seg(patientId)}');

  Uri clinicalPatientCreate() => _uri('clinical/patients');

  Uri clinicalPatientUpdate(String patientId) =>
      _uri('clinical/patients/${_seg(patientId)}');

  Uri clinicalPatientDelete(String patientId) =>
      _uri('clinical/patients/${_seg(patientId)}');

  // ─────────────────────────────────────────────
  // 📄 Clinical / Prescriptions
  // ─────────────────────────────────────────────

  Uri clinicalPrescriptionsList({
    String? patientId,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final pid = (patientId ?? '').trim();
    if (pid.isNotEmpty) query['patient_id'] = pid;

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('clinical/prescriptions', query: query);
  }

  Uri clinicalPrescriptionGet(String prescriptionId) =>
      _uri('clinical/prescriptions/${_seg(prescriptionId)}');

  Uri clinicalPrescriptionCreate() => _uri('clinical/prescriptions');

  Uri clinicalPrescriptionUpdate(String prescriptionId) =>
      _uri('clinical/prescriptions/${_seg(prescriptionId)}');

  Uri clinicalPrescriptionDelete(String prescriptionId) =>
      _uri('clinical/prescriptions/${_seg(prescriptionId)}');
}
