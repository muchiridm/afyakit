// lib/core/api/afyakit/routes/routes_occupational_health.dart
part of 'routes.dart';

/// Occupational Health (Occuwell) MedEx API.
/// All routes below require authenticated Occuwell app-staff access.
extension AfyaKitOccupationalHealthRoutes on AfyaKitRoutes {
  static const String _medex = 'occupational-health/medex';

  /// POST: create an examination from a verified campaign submission.
  /// Body: campaign_id, submission_id, account_number, profile_id,
  /// identity_confirmed: true; optional name_discrepancy_reason.
  Uri medexFromSubmission() => _uri('$_medex/from-submission');

  /// GET: list examinations; page 1..10000, per_page 1..100.
  Uri medexList({
    String? campaignId,
    String? profileId,
    int page = 1,
    int perPage = 50,
  }) {
    if (page < 1 || page > 10000) {
      throw RangeError.range(page, 1, 10000, 'page');
    }
    if (perPage < 1 || perPage > 100) {
      throw RangeError.range(perPage, 1, 100, 'perPage');
    }
    return _uri(
      _medex,
      query: {
        'page': '$page',
        'per_page': '$perPage',
        if (campaignId != null && campaignId.trim().isNotEmpty)
          'campaign_id': campaignId.trim(),
        if (profileId != null && profileId.trim().isNotEmpty)
          'profile_id': profileId.trim(),
      },
    );
  }

  /// GET: one examination.
  Uri medexGet(String medexId) => _medexId(medexId);

  /// PATCH: configure clinical requirements.
  Uri medexConfigureClinical(String medexId) =>
      _uri('${_medexIdPath(medexId)}/clinical');

  /// GET: clinical checklist.
  Uri medexChecklist(String medexId) =>
      _uri('${_medexIdPath(medexId)}/checklist');

  /// PUT: record fitness assessment.
  Uri medexFitness(String medexId) => _uri('${_medexIdPath(medexId)}/fitness');

  /// POST: sign the examination.
  Uri medexSign(String medexId) => _uri('${_medexIdPath(medexId)}/sign');

  /// GET: structured clinical report (JSON).
  Uri medexClinicalReport(String medexId) =>
      _uri('${_medexIdPath(medexId)}/clinical-report');

  /// POST: issue a fitness certificate.
  Uri medexIssueFitnessCertificate(String medexId) =>
      _uri('${_medexIdPath(medexId)}/fitness-certificate/issue');

  /// GET: structured fitness certificate (JSON).
  Uri medexFitnessCertificate(String medexId) =>
      _uri('${_medexIdPath(medexId)}/fitness-certificate');

  /// GET: PDF bytes (Content-Type: application/pdf).
  Uri medexClinicalReportPdf(String medexId) =>
      _uri('${_medexIdPath(medexId)}/clinical-report.pdf');

  /// GET: PDF bytes (Content-Type: application/pdf).
  Uri medexFitnessCertificatePdf(String medexId) =>
      _uri('${_medexIdPath(medexId)}/fitness-certificate.pdf');

  Uri _medexId(String id) => _uri(_medexIdPath(id));
  String _medexIdPath(String id) => '$_medex/${_seg(id)}';
}
