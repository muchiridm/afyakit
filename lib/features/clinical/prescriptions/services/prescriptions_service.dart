// lib/features/clinical/prescriptions/services/prescriptions_service.dart

import 'dart:typed_data';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/services/prescription_storage_paths.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PickedPrescriptionFile {
  const PickedPrescriptionFile({
    required this.fileName,
    required this.extension,
    required this.bytes,
  });

  final String fileName;
  final String extension;
  final Uint8List bytes;

  int get sizeBytes => bytes.lengthInBytes;
}

class PrescriptionsService {
  const PrescriptionsService({
    required this.api,
    required this.routes,
    FirebaseStorage? storage,
  }) : _storage = storage;

  final AfyaKitClient api;
  final AfyaKitRoutes routes;
  final FirebaseStorage? _storage;

  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  Future<List<Prescription>> list({
    String? profileId,
    bool? isActive,
    PrescriptionStatus? status,
    int perPage = 50,
    int page = 1,
  }) async {
    final pid = _nullable(profileId);

    final uri = pid != null
        ? routes.clinicalProfilePrescriptionsList(
            profileId: pid,
            isActive: isActive,
            status: status?.wireName,
            perPage: perPage,
            page: page,
          )
        : routes.clinicalPrescriptionsList(
            isActive: isActive,
            status: status?.wireName,
            perPage: perPage,
            page: page,
          );

    final response = await api.getUri<Object?>(uri);
    final body = _asMap(response.data);

    return _readPrescriptions(body['prescriptions']);
  }

  Future<Prescription> get({
    required String profileId,
    required String prescriptionId,
  }) async {
    final pid = _requiredId(profileId, 'profileId');
    final rxid = _requiredId(prescriptionId, 'prescriptionId');

    final response = await api.getUri<Object?>(
      routes.clinicalProfilePrescriptionGet(
        profileId: pid,
        prescriptionId: rxid,
      ),
    );

    final body = _asMap(response.data);

    return _readPrescription(body['prescription']);
  }

  Future<Prescription> create(PrescriptionCreateInput input) async {
    final pid = _requiredId(input.profileId, 'profileId');

    final response = await api.postUri<Object?>(
      routes.clinicalProfilePrescriptionCreate(pid),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readPrescription(body['prescription']);
  }

  Future<Prescription> approve({
    required String profileId,
    required String prescriptionId,
  }) async {
    final pid = _requiredId(profileId, 'profileId');
    final rxid = _requiredId(prescriptionId, 'prescriptionId');

    final response = await api.patchUri<Object?>(
      routes.clinicalProfilePrescriptionApprove(
        profileId: pid,
        prescriptionId: rxid,
      ),
    );

    final body = _asMap(response.data);

    return _readPrescription(body['prescription']);
  }

  Future<Prescription> update({
    required String profileId,
    required String prescriptionId,
    required PrescriptionUpdateInput input,
  }) async {
    final pid = _requiredId(profileId, 'profileId');
    final rxid = _requiredId(prescriptionId, 'prescriptionId');

    final response = await api.putUri<Object?>(
      routes.clinicalProfilePrescriptionUpdate(
        profileId: pid,
        prescriptionId: rxid,
      ),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readPrescription(body['prescription']);
  }

  Future<void> remove({
    required String profileId,
    required String prescriptionId,
  }) async {
    final pid = _requiredId(profileId, 'profileId');
    final rxid = _requiredId(prescriptionId, 'prescriptionId');

    await api.deleteUri<Object?>(
      routes.clinicalProfilePrescriptionDelete(
        profileId: pid,
        prescriptionId: rxid,
      ),
    );
  }

  Future<Prescription> uploadAndCreate({
    required String tenantId,
    required String profileId,
    required PickedPrescriptionFile file,
    String? note,
    String? prescribedOn,
  }) async {
    final cleanTenantId = _requiredId(tenantId, 'tenantId');

    final cleanProfileId = _requiredId(profileId, 'profileId');

    final uploadId = PrescriptionStoragePaths.newUploadId();

    final ext = PrescriptionStoragePaths.cleanExt(file.extension);

    final contentType = PrescriptionStoragePaths.contentTypeForExt(ext);

    final originalPath = PrescriptionStoragePaths.originalPath(
      tenantId: cleanTenantId,
      profileId: cleanProfileId,
      uploadId: uploadId,
      ext: ext,
    );

    final thumbPath = PrescriptionStoragePaths.thumbnailPath(
      tenantId: cleanTenantId,
      profileId: cleanProfileId,
      uploadId: uploadId,
    );

    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: <String, String>{
        'tenant_id': cleanTenantId,
        'profile_id': cleanProfileId,
        'upload_id': uploadId,
        'original_file_name': file.fileName,
        'document_type': 'prescription',
      },
    );

    await storage.ref(originalPath).putData(file.bytes, metadata);

    return create(
      PrescriptionCreateInput(
        profileId: cleanProfileId,
        fileName: file.fileName,
        storagePath: originalPath,
        originalStoragePath: originalPath,
        thumbnailStoragePath: thumbPath,
        contentType: contentType,
        sizeBytes: file.sizeBytes,
        note: _nullable(note),
        prescribedOn: _nullable(prescribedOn),
        status: PrescriptionStatus.uploaded,
        isActive: true,
      ),
    );
  }

  Future<String> downloadUrl(String storagePath) async {
    final path = _requiredId(storagePath, 'storagePath');

    return storage.ref(path).getDownloadURL();
  }

  static Prescription _readPrescription(Object? value) {
    return Prescription.fromJson(_asMap(value));
  }

  static List<Prescription> _readPrescriptions(Object? value) {
    return _asListOfMaps(
      value,
    ).map(Prescription.fromJson).toList(growable: false);
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    }

    throw const FormatException('Expected object map');
  }

  static List<Map<String, Object?>> _asListOfMaps(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (Map item) => item.map(
            (Object? key, Object? value) => MapEntry(key.toString(), value),
          ),
        )
        .toList(growable: false);
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

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
