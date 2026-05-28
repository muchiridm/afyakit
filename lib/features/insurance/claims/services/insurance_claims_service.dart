// lib/features/insurance/claims/services/insurance_claims_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/insurance/claims/models/insurance_claim.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final insuranceClaimsServiceProvider = FutureProvider<InsuranceClaimsService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final routes = AfyaKitRoutes(tenantId);
  final api = await ref.watch(afyakitClientFutureProvider.future);

  return InsuranceClaimsService(api: api, routes: routes);
});

class InsuranceClaimsService {
  const InsuranceClaimsService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  Future<List<InsuranceClaim>> list({
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
    InsuranceClaimStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final uri = routes.insuranceClaimsList(
      search: _nullable(search),
      membershipId: _nullable(membershipId),
      patientId: _nullable(patientId),
      patientNo: _nullable(patientNo),
      payerContactId: _nullable(payerContactId),
      invoiceId: _nullable(invoiceId),
      memberNo: _nullable(memberNo),
      scheme: _nullable(scheme),
      authCode: _nullable(authCode),
      claimNo: _nullable(claimNo),
      visitNo: _nullable(visitNo),
      prescriptionNo: _nullable(prescriptionNo),
      prescriptionId: _nullable(prescriptionId),
      status: status?.wire,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final body = _asMap(response.data);

    return _readClaims(body['claims']);
  }

  Future<InsuranceClaim> get(String claimId) async {
    final id = _requiredId(claimId, 'claimId');

    final response = await api.getUri<Object?>(routes.insuranceClaimGet(id));

    final body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  Future<InsuranceClaim> create(InsuranceClaimUpsertInput input) async {
    final response = await api.postUri<Object?>(
      routes.insuranceClaimCreate(),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  Future<InsuranceClaim> update(
    String claimId,
    InsuranceClaimUpsertInput input,
  ) async {
    final id = _requiredId(claimId, 'claimId');

    final response = await api.putUri<Object?>(
      routes.insuranceClaimUpdate(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  Future<void> delete(String claimId) async {
    final id = _requiredId(claimId, 'claimId');

    await api.deleteUri<Object?>(routes.insuranceClaimDelete(id));
  }

  Future<InsuranceClaim> attachClaimForm({
    required String claimId,
    required ClaimFormAttachmentInput input,
  }) async {
    final id = _requiredId(claimId, 'claimId');

    final response = await api.putUri<Object?>(
      routes.insuranceClaimAttachClaimForm(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  Future<InsuranceClaim> detachClaimForm(String claimId) async {
    final id = _requiredId(claimId, 'claimId');

    final response = await api.deleteUri<Object?>(
      routes.insuranceClaimDetachClaimForm(id),
    );

    final body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  Future<InsuranceClaim> attachPrescription({
    required String claimId,
    required ClaimPrescriptionAttachmentInput input,
  }) async {
    final id = _requiredId(claimId, 'claimId');

    final response = await api.putUri<Object?>(
      routes.insuranceClaimAttachPrescription(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  Future<InsuranceClaim> detachPrescription(String claimId) async {
    final id = _requiredId(claimId, 'claimId');

    final response = await api.deleteUri<Object?>(
      routes.insuranceClaimDetachPrescription(id),
    );

    final body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) return value;

    if (value is Map) {
      return value.map(
        (key, dynamic value) => MapEntry(key.toString(), value as Object?),
      );
    }

    throw const FormatException('Expected object map');
  }

  static List<Map<String, Object?>> _asListOfMaps(Object? value) {
    if (value is! List) return const <Map<String, Object?>>[];

    return value
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, dynamic value) => MapEntry(key.toString(), value as Object?),
          ),
        )
        .toList(growable: false);
  }

  static InsuranceClaim _readClaim(Object? value) {
    return InsuranceClaim.fromJson(_asMap(value));
  }

  static List<InsuranceClaim> _readClaims(Object? value) {
    return _asListOfMaps(
      value,
    ).map(InsuranceClaim.fromJson).toList(growable: false);
  }

  static String _requiredId(String value, String name) {
    final id = value.trim();

    if (id.isEmpty) {
      throw ArgumentError.value(value, name, '$name is empty');
    }

    return id;
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

class ClaimFormAttachmentInput {
  const ClaimFormAttachmentInput({
    this.fileName,
    this.url,
    this.storagePath,
    this.originalStoragePath,
    this.thumbnailStoragePath,
    this.contentType,
    this.sizeBytes,
    this.status,
  });

  final String? fileName;
  final String? url;
  final String? storagePath;
  final String? originalStoragePath;
  final String? thumbnailStoragePath;
  final String? contentType;
  final int? sizeBytes;
  final ClaimFormStatus? status;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'claim_form_file_name': fileName,
      'claim_form_url': url,
      'claim_form_storage_path': storagePath,
      'claim_form_original_storage_path': originalStoragePath,
      'claim_form_thumbnail_storage_path': thumbnailStoragePath,
      'claim_form_content_type': contentType,
      'claim_form_size_bytes': sizeBytes,
      'claim_form_status': status?.wire,
    }..removeWhere(_removeEmpty);
  }
}

class ClaimPrescriptionAttachmentInput {
  const ClaimPrescriptionAttachmentInput({
    this.prescriptionId,
    this.prescriptionNo,
    this.fileName,
    this.url,
    this.storagePath,
  });

  final String? prescriptionId;
  final String? prescriptionNo;
  final String? fileName;
  final String? url;
  final String? storagePath;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'prescription_id': prescriptionId,
      'prescription_no': prescriptionNo,
      'prescription_file_name': fileName,
      'prescription_url': url,
      'prescription_storage_path': storagePath,
    }..removeWhere(_removeEmpty);
  }
}

bool _removeEmpty(Object? _, Object? value) {
  if (value == null) return true;
  if (value is String && value.trim().isEmpty) return true;
  return false;
}
