// lib/features/insurance/claims/services/insurance_claims_service.dart

import 'dart:typed_data';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/insurance/claims/models/insurance_claim.dart';
import 'package:afyakit/features/insurance/claims/services/insurance_claim_form_storage_paths.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final insuranceClaimsServiceProvider = FutureProvider<InsuranceClaimsService>((
  ref,
) async {
  final String tenantId = ref.watch(tenantIdProvider);
  final AfyaKitRoutes routes = AfyaKitRoutes(tenantId);
  final AfyaKitClient api = await ref.watch(afyakitClientFutureProvider.future);

  return InsuranceClaimsService(tenantId: tenantId, api: api, routes: routes);
});

class PickedInsuranceClaimFile {
  const PickedInsuranceClaimFile({
    required this.fileName,
    required this.extension,
    required this.bytes,
  });

  final String fileName;
  final String extension;
  final Uint8List bytes;

  int get sizeBytes => bytes.lengthInBytes;
}

class UploadedInsuranceClaimFile {
  const UploadedInsuranceClaimFile({
    required this.fileName,
    required this.storagePath,
    required this.originalStoragePath,
    required this.thumbnailStoragePath,
    required this.downloadUrl,
    required this.contentType,
    required this.sizeBytes,
  });

  final String fileName;
  final String storagePath;
  final String originalStoragePath;
  final String thumbnailStoragePath;
  final String downloadUrl;
  final String contentType;
  final int sizeBytes;

  InsuranceClaimCreateInput toCreateInput({
    required String membershipId,
    String? invoiceId,
    String? invoiceNumber,
    String? prescriptionId,
    String? prescriptionNo,
    String? prescriberName,
    String? authCode,
    String? claimNo,
    String? visitNo,
    String? serviceDate,
    String? diagnosis,
    String? icd10Code,
    String? notes,
    InsuranceClaimStatus? status,
    bool? isActive,
  }) {
    return InsuranceClaimCreateInput(
      membershipId: membershipId,
      fileName: fileName,
      storagePath: storagePath,
      originalStoragePath: originalStoragePath,
      thumbnailStoragePath: thumbnailStoragePath,
      downloadUrl: downloadUrl,
      contentType: contentType,
      sizeBytes: sizeBytes,
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      prescriptionId: prescriptionId,
      prescriptionNo: prescriptionNo,
      prescriberName: prescriberName,
      authCode: authCode,
      claimNo: claimNo,
      visitNo: visitNo,
      serviceDate: serviceDate,
      diagnosis: diagnosis,
      icd10Code: icd10Code,
      notes: notes,
      status: status,
      isActive: isActive,
    );
  }
}

class InsuranceClaimsService {
  const InsuranceClaimsService({
    required this.tenantId,
    required this.api,
    required this.routes,
    FirebaseStorage? storage,
  }) : _storage = storage;

  final String tenantId;
  final AfyaKitClient api;
  final AfyaKitRoutes routes;
  final FirebaseStorage? _storage;

  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  Future<List<InsuranceClaim>> list({
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
    InsuranceClaimStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final Uri uri = routes.insuranceClaimsList(
      search: _nullable(search),
      membershipId: _nullable(membershipId),
      patientId: _nullable(patientId),
      payerContactId: _nullable(payerContactId),
      invoiceId: _nullable(invoiceId),
      memberNo: _nullable(memberNo),
      authCode: _nullable(authCode),
      claimNo: _nullable(claimNo),
      visitNo: _nullable(visitNo),
      prescriptionId: _nullable(prescriptionId),
      status: status?.wire,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final Map<String, Object?> body = _asMap(response.data);

    return _readClaims(body['claims']);
  }

  Future<List<InsuranceClaim>> listForPatient({
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
    InsuranceClaimStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final String cleanPatientId = _requiredId(patientId, 'patientId');

    final Uri uri = routes.insuranceClaimsListForPatient(
      patientId: cleanPatientId,
      search: _nullable(search),
      membershipId: _nullable(membershipId),
      payerContactId: _nullable(payerContactId),
      invoiceId: _nullable(invoiceId),
      memberNo: _nullable(memberNo),
      authCode: _nullable(authCode),
      claimNo: _nullable(claimNo),
      visitNo: _nullable(visitNo),
      prescriptionId: _nullable(prescriptionId),
      status: status?.wire,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final Map<String, Object?> body = _asMap(response.data);

    return _readClaims(body['claims']);
  }

  Future<InsuranceClaim> get({
    required String patientId,
    required String claimId,
  }) async {
    final String cleanPatientId = _requiredId(patientId, 'patientId');
    final String cleanClaimId = _requiredId(claimId, 'claimId');

    final response = await api.getUri<Object?>(
      routes.insuranceClaimGet(
        patientId: cleanPatientId,
        claimId: cleanClaimId,
      ),
    );

    final Map<String, Object?> body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  Future<InsuranceClaim> create({
    required String patientId,
    required InsuranceClaimCreateInput input,
  }) async {
    final String cleanPatientId = _requiredId(patientId, 'patientId');

    final response = await api.postUri<Object?>(
      routes.insuranceClaimCreate(patientId: cleanPatientId),
      data: input.toJson(),
    );

    final Map<String, Object?> body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  Future<InsuranceClaim> update({
    required String patientId,
    required String claimId,
    required InsuranceClaimUpdateInput input,
  }) async {
    final String cleanPatientId = _requiredId(patientId, 'patientId');
    final String cleanClaimId = _requiredId(claimId, 'claimId');

    final response = await api.putUri<Object?>(
      routes.insuranceClaimUpdate(
        patientId: cleanPatientId,
        claimId: cleanClaimId,
      ),
      data: input.toJson(),
    );

    final Map<String, Object?> body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  Future<void> delete({
    required String patientId,
    required String claimId,
  }) async {
    final String cleanPatientId = _requiredId(patientId, 'patientId');
    final String cleanClaimId = _requiredId(claimId, 'claimId');

    await api.deleteUri<Object?>(
      routes.insuranceClaimDelete(
        patientId: cleanPatientId,
        claimId: cleanClaimId,
      ),
    );
  }

  Future<UploadedInsuranceClaimFile> uploadClaimFile({
    required String patientId,
    required PickedInsuranceClaimFile file,
  }) async {
    final String cleanTenantId = _requiredId(tenantId, 'tenantId');
    final String cleanPatientId = _requiredId(patientId, 'patientId');

    final String uploadId = InsuranceClaimStoragePaths.newUploadId();
    final String ext = InsuranceClaimStoragePaths.cleanExt(file.extension);
    final String contentType = InsuranceClaimStoragePaths.contentTypeForExt(
      ext,
    );

    final String originalPath = InsuranceClaimStoragePaths.originalPath(
      tenantId: cleanTenantId,
      patientId: cleanPatientId,
      uploadId: uploadId,
      ext: ext,
    );

    final String thumbnailPath = InsuranceClaimStoragePaths.thumbnailPath(
      tenantId: cleanTenantId,
      patientId: cleanPatientId,
      uploadId: uploadId,
    );

    final SettableMetadata metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: <String, String>{
        'tenant_id': cleanTenantId,
        'patient_id': cleanPatientId,
        'upload_id': uploadId,
        'document_type': 'insurance_claim',
        'original_file_name': file.fileName,
      },
    );

    final Reference ref = storage.ref(originalPath);

    await ref.putData(file.bytes, metadata);

    final String downloadUrl = await ref.getDownloadURL();

    return UploadedInsuranceClaimFile(
      fileName: file.fileName,
      storagePath: originalPath,
      originalStoragePath: originalPath,
      thumbnailStoragePath: thumbnailPath,
      downloadUrl: downloadUrl,
      contentType: contentType,
      sizeBytes: file.sizeBytes,
    );
  }

  Future<InsuranceClaim> uploadClaimFileAndCreate({
    required String patientId,
    required String membershipId,
    required PickedInsuranceClaimFile file,
    String? invoiceId,
    String? invoiceNumber,
    String? prescriptionId,
    String? prescriptionNo,
    String? prescriberName,
    String? authCode,
    String? claimNo,
    String? visitNo,
    String? serviceDate,
    String? diagnosis,
    String? icd10Code,
    String? notes,
    InsuranceClaimStatus? status,
    bool? isActive,
  }) async {
    final UploadedInsuranceClaimFile uploaded = await uploadClaimFile(
      patientId: patientId,
      file: file,
    );

    return create(
      patientId: patientId,
      input: uploaded.toCreateInput(
        membershipId: membershipId,
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        prescriptionId: prescriptionId,
        prescriptionNo: prescriptionNo,
        prescriberName: prescriberName,
        authCode: authCode,
        claimNo: claimNo,
        visitNo: visitNo,
        serviceDate: serviceDate,
        diagnosis: diagnosis,
        icd10Code: icd10Code,
        notes: notes,
        status: status,
        isActive: isActive,
      ),
    );
  }

  static InsuranceClaim _readClaim(Object? value) {
    return InsuranceClaim.fromJson(_asMap(value));
  }

  static List<InsuranceClaim> _readClaims(Object? value) {
    return _asListOfMaps(
      value,
    ).map(InsuranceClaim.fromJson).toList(growable: false);
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) return value;

    if (value is Map) {
      final Map<String, Object?> output = <String, Object?>{};

      for (final MapEntry<Object?, Object?> entry
          in value.entries.cast<MapEntry<Object?, Object?>>()) {
        output[entry.key.toString()] = entry.value;
      }

      return output;
    }

    throw const FormatException('Expected object map');
  }

  static List<Map<String, Object?>> _asListOfMaps(Object? value) {
    if (value is! List) return const <Map<String, Object?>>[];

    final List<Map<String, Object?>> output = <Map<String, Object?>>[];

    for (final Object? item in value) {
      if (item is Map || item is Map<String, Object?>) {
        output.add(_asMap(item));
      }
    }

    return output;
  }

  static String _requiredId(String value, String name) {
    final String id = value.trim();

    if (id.isEmpty) {
      throw ArgumentError.value(value, name, '$name is empty');
    }

    return id;
  }

  static String? _nullable(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
