part of 'routes.dart';

extension AfyaKitClinicalRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🧑‍⚕️ Clinical / Patients
  // ─────────────────────────────────────────────

  Uri clinicalPatientsList({
    String? search,
    String? contactId,
    String? relationship,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final s = (search ?? '').trim();
    if (s.isNotEmpty) query['search'] = s;

    final cid = (contactId ?? '').trim();
    if (cid.isNotEmpty) query['contact_id'] = cid;

    final rel = (relationship ?? '').trim();
    if (rel.isNotEmpty) query['relationship'] = rel;

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('clinical/patients', query: query);
  }

  /// GET /clinical/patients/:patientId
  Uri clinicalPatientGet(String patientId) =>
      _uri('clinical/patients/${_seg(patientId)}');

  /// POST /clinical/patients
  Uri clinicalPatientCreate() => _uri('clinical/patients');

  /// PUT /clinical/patients/:patientId
  Uri clinicalPatientUpdate(String patientId) =>
      _uri('clinical/patients/${_seg(patientId)}');

  /// DELETE /clinical/patients/:patientId
  Uri clinicalPatientDelete(String patientId) =>
      _uri('clinical/patients/${_seg(patientId)}');

  /// POST /clinical/patients/:patientId/link-self
  Uri clinicalPatientLinkSelf(String patientId) =>
      _uri('clinical/patients/${_seg(patientId)}/link-self');

  // ─────────────────────────────────────────────
  // 🧾 Clinical / Patient link requests
  // ─────────────────────────────────────────────

  /// POST /clinical/patients/:patientId/link-requests
  Uri clinicalPatientLinkRequestCreate(String patientId) =>
      _uri('clinical/patients/${_seg(patientId)}/link-requests');

  /// GET /clinical/patients/link-requests
  Uri clinicalPatientLinkRequestsList({
    String? status,
    String? patientId,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final s = (status ?? '').trim();
    if (s.isNotEmpty) query['status'] = s;

    final pid = (patientId ?? '').trim();
    if (pid.isNotEmpty) query['patient_id'] = pid;

    return _uri('clinical/patients/link-requests', query: query);
  }

  /// POST /clinical/patients/link-requests/:requestId/approve
  Uri clinicalPatientLinkRequestApprove(String requestId) =>
      _uri('clinical/patients/link-requests/${_seg(requestId)}/approve');

  /// POST /clinical/patients/link-requests/:requestId/reject
  Uri clinicalPatientLinkRequestReject(String requestId) =>
      _uri('clinical/patients/link-requests/${_seg(requestId)}/reject');

  // ─────────────────────────────────────────────
  // 🔗 Clinical / Staff direct patient-contact links
  // ─────────────────────────────────────────────

  /// POST /clinical/patients/:patientId/linked-contacts
  Uri clinicalPatientLinkedContactCreate(String patientId) =>
      _uri('clinical/patients/${_seg(patientId)}/linked-contacts');

  /// DELETE /clinical/patients/:patientId/linked-contacts/:contactId
  Uri clinicalPatientLinkedContactDelete({
    required String patientId,
    required String contactId,
  }) {
    return _uri(
      'clinical/patients/${_seg(patientId)}/linked-contacts/${_seg(contactId)}',
    );
  }

  // ─────────────────────────────────────────────
  // 📄 Clinical / Prescriptions
  // ─────────────────────────────────────────────

  /// Staff global list:
  /// GET /clinical/prescriptions?patient_id=...
  Uri clinicalPrescriptionsList({
    String? patientId,
    bool? isActive,
    String? status,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final pid = (patientId ?? '').trim();
    if (pid.isNotEmpty) query['patient_id'] = pid;

    final st = (status ?? '').trim();
    if (st.isNotEmpty) query['status'] = st;

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri('clinical/prescriptions', query: query);
  }

  /// GET /clinical/patients/:patientId/prescriptions
  Uri clinicalPatientPrescriptionsList({
    required String patientId,
    bool? isActive,
    String? status,
    int perPage = 50,
    int page = 1,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final st = (status ?? '').trim();
    if (st.isNotEmpty) query['status'] = st;

    if (isActive != null) {
      query['is_active'] = isActive ? 'true' : 'false';
    }

    return _uri(
      'clinical/patients/${_seg(patientId)}/prescriptions',
      query: query,
    );
  }

  /// GET /clinical/patients/:patientId/prescriptions/:prescriptionId
  Uri clinicalPatientPrescriptionGet({
    required String patientId,
    required String prescriptionId,
  }) {
    return _uri(
      'clinical/patients/${_seg(patientId)}/prescriptions/${_seg(prescriptionId)}',
    );
  }

  /// POST /clinical/patients/:patientId/prescriptions
  Uri clinicalPatientPrescriptionCreate(String patientId) {
    return _uri('clinical/patients/${_seg(patientId)}/prescriptions');
  }

  /// PATCH /clinical/patients/:patientId/prescriptions/:prescriptionId/approve
  Uri clinicalPatientPrescriptionApprove({
    required String patientId,
    required String prescriptionId,
  }) {
    return _uri(
      'clinical/patients/${_seg(patientId)}/prescriptions/${_seg(prescriptionId)}/approve',
    );
  }

  /// PUT /clinical/patients/:patientId/prescriptions/:prescriptionId
  Uri clinicalPatientPrescriptionUpdate({
    required String patientId,
    required String prescriptionId,
  }) {
    return _uri(
      'clinical/patients/${_seg(patientId)}/prescriptions/${_seg(prescriptionId)}',
    );
  }

  /// DELETE /clinical/patients/:patientId/prescriptions/:prescriptionId
  Uri clinicalPatientPrescriptionDelete({
    required String patientId,
    required String prescriptionId,
  }) {
    return _uri(
      'clinical/patients/${_seg(patientId)}/prescriptions/${_seg(prescriptionId)}',
    );
  }
}
