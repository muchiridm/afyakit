// lib/features/clinical/prescriptions/services/prescriptions_service.dart
import 'dart:typed_data';
import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/storage/profile_storage_access.dart';
import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/services/prescription_storage_paths.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PickedPrescriptionFile {
  const PickedPrescriptionFile({
    required this.fileName, required this.extension, required this.bytes,
  });
  final String fileName;
  final String extension;
  final Uint8List bytes;
  int get sizeBytes => bytes.lengthInBytes;
}

class PrescriptionsService {
  const PrescriptionsService({
    required this.appId,
    required this.api, required this.routes, FirebaseStorage? storage,
  }) : _storage = storage;

  final String appId;
  Uri _scopeUri(Uri uri) => ProfileStorageAccess.scopedUri(uri, appId);

  final AfyaKitClient api;
  final AfyaKitRoutes routes;
  final FirebaseStorage? _storage;
  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  Future<List<Prescription>> list({
    String? profileId, bool? isActive, PrescriptionStatus? status,
    int perPage = 50, int page = 1,
  }) async {
    final pid = _nullable(profileId);
    final uri = pid != null
        ? routes.clinicalProfilePrescriptionsList(
            profileId: pid, isActive: isActive, status: status?.wireName,
            perPage: perPage, page: page,
          )
        : routes.clinicalPrescriptionsList(
            isActive: isActive, status: status?.wireName, perPage: perPage, page: page,
          );
    final response = await api.getUri<Object?>(_scopeUri(uri));
    return _readPrescriptions(_asMap(response.data)['prescriptions']);
  }

  Future<Prescription> get({required String profileId, required String prescriptionId}) async {
    final response = await api.getUri<Object?>(_scopeUri(routes.clinicalProfilePrescriptionGet(
        profileId: _requiredId(profileId, 'profileId'),
        prescriptionId: _requiredId(prescriptionId, 'prescriptionId'),
      )),
    );
    return _readPrescription(_asMap(response.data)['prescription']);
  }

  Future<Prescription> create(PrescriptionCreateInput input) async {
    final response = await api.postUri<Object?>(_scopeUri(routes.clinicalProfilePrescriptionCreate(_requiredId(input.profileId, 'profileId'))),
      data: input.toJson(),
    );
    return _readPrescription(_asMap(response.data)['prescription']);
  }

  Future<Prescription> approve({required String profileId, required String prescriptionId}) async {
    final response = await api.patchUri<Object?>(_scopeUri(routes.clinicalProfilePrescriptionApprove(
        profileId: _requiredId(profileId, 'profileId'),
        prescriptionId: _requiredId(prescriptionId, 'prescriptionId'),
      )),
    );
    return _readPrescription(_asMap(response.data)['prescription']);
  }

  Future<Prescription> update({
    required String profileId, required String prescriptionId,
    required PrescriptionUpdateInput input,
  }) async {
    final response = await api.putUri<Object?>(_scopeUri(routes.clinicalProfilePrescriptionUpdate(
        profileId: _requiredId(profileId, 'profileId'),
        prescriptionId: _requiredId(prescriptionId, 'prescriptionId'),
      )),
      data: input.toJson(),
    );
    return _readPrescription(_asMap(response.data)['prescription']);
  }

  Future<void> remove({required String profileId, required String prescriptionId}) async {
    await api.deleteUri<Object?>(_scopeUri(routes.clinicalProfilePrescriptionDelete(
        profileId: _requiredId(profileId, 'profileId'),
        prescriptionId: _requiredId(prescriptionId, 'prescriptionId'),
      )),
    );
  }

  Future<Prescription> uploadAndCreate({
    required String tenantId, required String profileId,
    required PickedPrescriptionFile file, String? note, String? prescribedOn,
  }) async {
    final tid = _requiredId(tenantId, 'tenantId');
    final pid = _requiredId(profileId, 'profileId');
    if (file.sizeBytes == 0 || file.sizeBytes > PrescriptionStoragePaths.maxFileBytes) {
      throw ArgumentError('Choose a non-empty file no larger than 20 MiB');
    }
    final uploadId = PrescriptionStoragePaths.newUploadId();
    final ext = PrescriptionStoragePaths.cleanExt(file.extension);
    final contentType = PrescriptionStoragePaths.contentTypeForExt(ext);
    final originalPath = PrescriptionStoragePaths.originalPath(
      tenantId: tid, appId: appId, profileId: pid, uploadId: uploadId, ext: ext,
    );
    final context = await ProfileStorageAccess.uploadMetadata(
      api: api,
      collectionUri: routes.clinicalProfilePrescriptionCreate(pid),
      tenantId: tid, profileId: pid, appId: appId,
    );
    await storage.ref(originalPath).putData(file.bytes, SettableMetadata(
      contentType: contentType,
      customMetadata: {
        ...context, 'upload_id': uploadId,
        'original_file_name': file.fileName, 'document_type': 'prescription',
      },
    ));
    return create(PrescriptionCreateInput(
      profileId: pid, fileName: file.fileName,
      storagePath: originalPath, originalStoragePath: originalPath,
      contentType: contentType, sizeBytes: file.sizeBytes,
      note: _nullable(note), prescribedOn: _nullable(prescribedOn),
      status: PrescriptionStatus.uploaded, isActive: true,
    ));
  }

  Future<String> downloadUrl(String storagePath) async {
    final path = _requiredId(storagePath, 'storagePath');
    final parts = path.split('/');
    String profileId;
    if (parts.length >= 9 && parts[0] == 'tenants' && parts[2] == 'apps' &&
        parts[4] == 'health_profiles' && parts[6] == 'prescriptions') {
      profileId = parts[5];
    } else if (parts.length >= 6 && parts[0] == 'tenants' &&
        (parts[2] == 'clinical_profiles' || parts[2] == 'health_profiles') &&
        parts[4] == 'prescriptions') {
      profileId = parts[3];
    } else {
      throw ArgumentError('Unrecognised prescription Storage path');
    }
    return ProfileStorageAccess.downloadUrl(
      appId: appId,
      api: api, collectionUri: routes.clinicalProfilePrescriptionCreate(profileId),
      storagePath: path,
    );
  }

  static Prescription _readPrescription(Object? value) => Prescription.fromJson(_asMap(value));
  static List<Prescription> _readPrescriptions(Object? value) =>
      _asListOfMaps(value).map(Prescription.fromJson).toList(growable: false);

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((Object? key, Object? value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Expected object map');
  }

  static List<Map<String, Object?>> _asListOfMaps(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((Map item) => item.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    )).toList(growable: false);
  }

  static String _requiredId(String value, String name) {
    final id = value.trim();
    if (id.isEmpty) throw ArgumentError.value(value, name, '$name is empty');
    return id;
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
