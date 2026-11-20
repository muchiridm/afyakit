// lib/features/clinical/prescriptions/prescriptions_service.dart

import 'dart:typed_data';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/clinical/prescriptions/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/prescription_storage_paths.dart';
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
    required this.appId,
    required this.api,
    required this.routes,
    FirebaseStorage? storage,
  }) : _storage = storage;

  final String appId;
  final AfyaKitClient api;
  final AfyaKitRoutes routes;
  final FirebaseStorage? _storage;

  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  // ─────────────────────────────────────────────
  // API scope
  // ─────────────────────────────────────────────

  Uri _scopeUri(Uri uri) {
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(appId)) {
      throw ArgumentError('Active appId is required');
    }

    return uri.replace(
      queryParameters: {...uri.queryParameters, 'appId': appId},
    );
  }


  // ─────────────────────────────────────────────
  // Queries
  // ─────────────────────────────────────────────

  Future<List<Prescription>> list({
    String? profileId,
    bool? isActive,
    PrescriptionStatus? status,
    int perPage = 50,
    int page = 1,
  }) async {
    final pid = _nullable(profileId);

    final uri = routes.clinicalPrescriptionsList(
      profileId: pid,
      isActive: isActive,
      status: status?.wireName,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(_scopeUri(uri));

    return _readPrescriptions(_asMap(response.data)['prescriptions']);
  }

  Future<Prescription> get({
    required String profileId,
    required String prescriptionId,
  }) async {
    _requiredId(profileId, 'profileId');
    final uri = routes.clinicalPrescriptionGet(
      _requiredId(prescriptionId, 'prescriptionId'),
    );

    final response = await api.getUri<Object?>(_scopeUri(uri));

    return _readPrescription(_asMap(response.data)['prescription']);
  }

  // ─────────────────────────────────────────────
  // Mutations
  // ─────────────────────────────────────────────

  Future<Prescription> create(PrescriptionCreateInput input) async {
    _requiredId(input.profileId, 'profileId');
    _requiredId(input.prescriptionId, 'prescriptionId');
    final uri = routes.clinicalPrescriptionCreate();

    final response = await api.postUri<Object?>(
      _scopeUri(uri),
      data: input.toJson(),
    );

    return _readPrescription(_asMap(response.data)['prescription']);
  }

  Future<Prescription> approve({
    required String profileId,
    required String prescriptionId,
  }) async {
    _requiredId(profileId, 'profileId');
    final uri = routes.clinicalPrescriptionApprove(
      _requiredId(prescriptionId, 'prescriptionId'),
    );

    final response = await api.patchUri<Object?>(_scopeUri(uri));

    return _readPrescription(_asMap(response.data)['prescription']);
  }

  Future<Prescription> update({
    required String profileId,
    required String prescriptionId,
    required PrescriptionUpdateInput input,
  }) async {
    _requiredId(profileId, 'profileId');
    final uri = routes.clinicalPrescriptionUpdate(
      _requiredId(prescriptionId, 'prescriptionId'),
    );

    final response = await api.putUri<Object?>(
      _scopeUri(uri),
      data: input.toJson(),
    );

    return _readPrescription(_asMap(response.data)['prescription']);
  }

  Future<void> remove({
    required String profileId,
    required String prescriptionId,
  }) async {
    _requiredId(profileId, 'profileId');
    final uri = routes.clinicalPrescriptionDelete(
      _requiredId(prescriptionId, 'prescriptionId'),
    );

    await api.deleteUri<Object?>(_scopeUri(uri));
  }

  // ─────────────────────────────────────────────
  // Prescription upload authorization
  // ─────────────────────────────────────────────

  Future<Map<String, String>> _uploadMetadata({
    required String tenantId,
    required String profileId,
  }) async {
    final response = await api.postUri<Object?>(
      _scopeUri(routes.clinicalPrescriptionStorageAccess()),
      data: <String, Object?>{'profile_id': profileId},
    );

    final body = _asMap(response.data);
    final context = _asMap(body['storage_access']);

    if (context['tenant_id'] != tenantId ||
        context['profile_id'] != profileId ||
        context['app_id'] != appId ||
        context['uploaded_by_uid'] is! String ||
        context['prescription_id'] is! String ||
        context['storage_prefix'] is! String) {
      throw StateError('Storage scope does not match the active API session');
    }

    return <String, String>{
      'tenant_id': tenantId,
      'app_id': appId,
      'profile_id': profileId,
      'uploaded_by_uid': _requiredId(context['uploaded_by_uid'] as String, 'uploaded_by_uid'),
      'prescription_id': _requiredId(context['prescription_id'] as String, 'prescription_id'),
      'storage_prefix': _requiredId(context['storage_prefix'] as String, 'storage_prefix'),
    };
  }

  // ─────────────────────────────────────────────
  // Prescription upload
  // ─────────────────────────────────────────────

  Future<Prescription> uploadAndCreate({
    required String tenantId,
    required String profileId,
    required PickedPrescriptionFile file,
    String? note,
    String? prescribedOn,
  }) async {
    final tid = _requiredId(tenantId, 'tenantId');
    final pid = _requiredId(profileId, 'profileId');

    if (file.sizeBytes == 0 ||
        file.sizeBytes > PrescriptionStoragePaths.maxFileBytes) {
      throw ArgumentError('Choose a non-empty file no larger than 20 MiB');
    }

    final ext = PrescriptionStoragePaths.cleanExt(file.extension);
    final contentType = PrescriptionStoragePaths.contentTypeForExt(ext);
    final fileName = _requiredId(file.fileName, 'fileName');
    final context = await _uploadMetadata(tenantId: tid, profileId: pid);
    final prescriptionId = context['prescription_id']!;
    final prefix = context['storage_prefix']!;
    final originalPath = PrescriptionStoragePaths.originalPath(
      storagePrefix: prefix,
      ext: ext,
    );

    await storage
        .ref(originalPath)
        .putData(
          file.bytes,
          SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'tenant_id': tid,
              'app_id': appId,
              'profile_id': pid,
              'uploaded_by_uid': context['uploaded_by_uid']!,
              'prescription_id': prescriptionId,
              'original_file_name': fileName,
              'document_type': 'prescription',
            },
          ),
        );

    return create(
      PrescriptionCreateInput(
        profileId: pid,
        prescriptionId: prescriptionId,
        fileName: fileName,
        storagePath: originalPath,
        originalStoragePath: originalPath,
        contentType: contentType,
        sizeBytes: file.sizeBytes,
        note: _nullable(note),
        prescribedOn: _nullable(prescribedOn),
        status: PrescriptionStatus.uploaded,
        isActive: true,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Prescription download
  // ─────────────────────────────────────────────

  Future<String> downloadUrl({required String prescriptionId}) async {
    final id = _requiredId(prescriptionId, 'prescriptionId');
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw ArgumentError('Invalid prescription ID');
    }
    final response = await api.postUri<Object?>(
      _scopeUri(routes.clinicalPrescriptionStorageDownload(id)),
      data: <String, Object?>{},
    );

    final body = _asMap(response.data);
    final url = body['download_url'];

    if (url is! String || url.trim().isEmpty) {
      throw const FormatException('Missing download URL');
    }

    final uri = Uri.tryParse(url);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid prescription download URL');
    }

    return url;
  }

  // ─────────────────────────────────────────────
  // Response parsing
  // ─────────────────────────────────────────────

  static Prescription _readPrescription(Object? value) =>
      Prescription.fromJson(_asMap(value));

  static List<Prescription> _readPrescriptions(Object? value) =>
      _asListOfMaps(value).map(Prescription.fromJson).toList(growable: false);

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
      return const [];
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

  // ─────────────────────────────────────────────
  // Validation
  // ─────────────────────────────────────────────

  static String _requiredId(String value, String name) {
    final id = value.trim();

    if (id.isEmpty) {
      throw ArgumentError.value(value, name, '$name is empty');
    }

    return id;
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
