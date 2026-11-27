// lib/features/clinical/prescriptions/prescriptions_service.dart

import 'dart:typed_data';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/clinical/prescriptions/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/prescription_storage_paths.dart';
import 'package:afyakit/core/files/private_file.dart';
import 'package:afyakit/features/records/documents/document_upload_service.dart';

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
    required this.isCurrent,
    this.uploader = const SignedDocumentUploadService(),
  });

  final String appId;
  final AfyaKitClient api;
  final AfyaKitRoutes routes;
  final bool Function() isCurrent;
  final SignedDocumentUploadService uploader;

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

  Future<List<String>> access(String profileId) async {
    if (!isCurrent()) throw StateError('Session changed');
    final base = routes.clinicalPrescriptionsList(profileId: profileId);
    final response = await api.getUri<Object?>(
      _scopeUri(base.replace(path: '${base.path}/access')),
    );
    if (!isCurrent()) throw StateError('Session changed');
    return (_asMap(response.data)['allowed_actions'] as List? ?? [])
        .whereType<String>()
        .toList();
  }

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

    if (!isCurrent()) throw StateError('Session changed');
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

    if (!isCurrent()) throw StateError('Session changed');
    return _readPrescription(_asMap(response.data)['prescription']);
  }

  // ─────────────────────────────────────────────
  // Mutations
  // ─────────────────────────────────────────────

  Future<Prescription> create(PrescriptionCreateInput input) async {
    if (!isCurrent()) throw StateError('File session changed');
    _requiredId(input.profileId, 'profileId');
    _requiredId(input.prescriptionId, 'prescriptionId');
    final uri = routes.clinicalPrescriptionCreate();

    final response = await api.postUri<Object?>(
      _scopeUri(uri),
      data: input.toJson(),
    );

    if (!isCurrent()) throw StateError('Session changed');
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

    if (!isCurrent()) throw StateError('Session changed');
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

    if (!isCurrent()) throw StateError('Session changed');
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
    if (!isCurrent()) throw StateError('File session changed');
    final response = await api.postUri<Object?>(
      _scopeUri(routes.clinicalPrescriptionStorageAccess()),
      data: {
        'profile_id': pid,
        'file_name': fileName,
        'content_type': contentType,
        'size_bytes': file.sizeBytes,
      },
    );
    if (!isCurrent()) throw StateError('File session changed');
    final context = _asMap(_asMap(response.data)['storage_access']);
    if (context['tenant_id'] != tid ||
        context['app_id'] != appId ||
        context['profile_id'] != pid ||
        context['prescription_id'] != context['document_id']) {
      throw StateError('Upload scope mismatch');
    }
    final reservation = DocumentUploadReservation.fromJson(context);
    final prescriptionId = reservation.documentId;
    final originalPath = context['storage_path'] as String;
    await uploader.upload(
      reservation,
      PickedDocumentFile(fileName: fileName, extension: ext, bytes: file.bytes),
    );
    if (!isCurrent()) throw StateError('File session changed');

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

  Future<PrivateFile> download({
    required String prescriptionId,
    required String fileName,
  }) {
    final id = _requiredId(prescriptionId, 'prescriptionId');
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw ArgumentError('Invalid prescription ID');
    }
    return downloadPrivateFile(
      api,
      _scopeUri(routes.clinicalPrescriptionStorageDownload(id)),
      fileName,
      isCurrent,
    );
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
