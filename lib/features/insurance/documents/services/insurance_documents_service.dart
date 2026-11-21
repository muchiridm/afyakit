// lib/features/insurance/documents/services/insurance_documents_service.dart

import 'dart:typed_data';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/storage/document_app_provider.dart';
import 'package:afyakit/core/storage/document_storage_paths.dart';
import 'package:afyakit/core/storage/document_upload_service.dart';
import 'package:afyakit/core/storage/profile_storage_access.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/features/insurance/documents/models/insurance_document.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final insuranceDocumentsServiceProvider =
    FutureProvider<InsuranceDocumentsService>((ref) async {
      final tenantId = ref.watch(tenantIdProvider);
      final appId = ref.watch(documentAppIdProvider);

      final api = await ref.watch(afyakitClientFutureProvider.future);

      return InsuranceDocumentsService(
        tenantId: tenantId,
        appId: appId,
        api: api,
        routes: AfyaKitRoutes(tenantId),
      );
    });

class PickedInsuranceDocumentFile {
  const PickedInsuranceDocumentFile({
    required this.fileName,
    required this.extension,
    required this.bytes,
  });

  final String fileName;
  final String extension;
  final Uint8List bytes;

  int get sizeBytes => bytes.lengthInBytes;
}

class UploadedInsuranceDocumentFile {
  const UploadedInsuranceDocumentFile({
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

  InsuranceDocumentCreateInput toCreateInput({
    String? claimPackId,
    required InsuranceDocumentType documentType,
    String? membershipId,
    String? payerContactId,
    String? payerDisplayName,
    String? title,
    String? notes,
    InsuranceDocumentStatus? status,
    bool? isActive,
  }) {
    return InsuranceDocumentCreateInput(
      claimPackId: claimPackId,
      documentType: documentType,
      fileName: fileName,
      storagePath: storagePath,
      originalStoragePath: originalStoragePath,
      thumbnailStoragePath: thumbnailStoragePath.isEmpty
          ? null
          : thumbnailStoragePath,
      contentType: contentType,
      sizeBytes: sizeBytes,
      membershipId: membershipId,
      payerContactId: payerContactId,
      payerDisplayName: payerDisplayName,
      title: title,
      notes: notes,
      status: status,
      isActive: isActive,
    );
  }
}

class InsuranceDocumentsService {
  const InsuranceDocumentsService({
    required this.appId,
    required this.tenantId,
    required this.api,
    required this.routes,
    FirebaseStorage? storage,
  }) : _storage = storage;

  final String tenantId;
  final String appId;
  final AfyaKitClient api;
  final AfyaKitRoutes routes;
  final FirebaseStorage? _storage;

  Uri _scopeUri(Uri uri) => ProfileStorageAccess.scopedUri(uri, appId);

  DocumentUploadService get _uploader => DocumentUploadService(
    api: api,
    tenantId: tenantId,
    appId: appId,
    storage: _storage,
  );

  // ─────────────────────────────────────────────
  // Document CRUD
  // ─────────────────────────────────────────────

  Future<List<InsuranceDocument>> list({
    String? search,
    String? profileId,
    String? claimPackId,
    InsuranceDocumentType? documentType,
    String? membershipId,
    String? payerContactId,
    InsuranceDocumentStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final uri = routes.recordsDocumentsList(
      search: _nullable(search),
      profileId: _nullable(profileId),
      claimPackId: _nullable(claimPackId),
      documentType: documentType?.wire,
      membershipId: _nullable(membershipId),
      payerContactId: _nullable(payerContactId),
      status: status?.wire,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(_scopeUri(uri));

    final body = _asMap(response.data);
    return _readDocuments(body['documents']);
  }

  Future<List<InsuranceDocument>> listForProfile({
    required String profileId,
    String? search,
    String? claimPackId,
    InsuranceDocumentType? documentType,
    String? membershipId,
    String? payerContactId,
    InsuranceDocumentStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final pid = _requiredId(profileId, 'profileId');

    final uri = routes.recordsDocumentsListForProfile(
      profileId: pid,
      search: _nullable(search),
      claimPackId: _nullable(claimPackId),
      documentType: documentType?.wire,
      membershipId: _nullable(membershipId),
      payerContactId: _nullable(payerContactId),
      status: status?.wire,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(_scopeUri(uri));

    final body = _asMap(response.data);
    return _readDocuments(body['documents']);
  }

  Future<InsuranceDocument> get({
    required String profileId,
    required String documentId,
  }) async {
    final response = await api.getUri<Object?>(
      _scopeUri(
        routes.recordsDocumentGet(
          profileId: _requiredId(profileId, 'profileId'),
          documentId: _requiredId(documentId, 'documentId'),
        ),
      ),
    );

    return _readDocument(_asMap(response.data)['document']);
  }

  Future<InsuranceDocument> create({
    required String profileId,
    required InsuranceDocumentCreateInput input,
  }) async {
    final response = await api.postUri<Object?>(
      _scopeUri(
        routes.recordsDocumentCreate(
          profileId: _requiredId(profileId, 'profileId'),
        ),
      ),
      data: input.toJson(),
    );

    return _readDocument(_asMap(response.data)['document']);
  }

  Future<InsuranceDocument> update({
    required String profileId,
    required String documentId,
    required InsuranceDocumentUpdateInput input,
  }) async {
    final response = await api.putUri<Object?>(
      _scopeUri(
        routes.recordsDocumentUpdate(
          profileId: _requiredId(profileId, 'profileId'),
          documentId: _requiredId(documentId, 'documentId'),
        ),
      ),
      data: input.toJson(),
    );

    return _readDocument(_asMap(response.data)['document']);
  }

  Future<void> delete({
    required String profileId,
    required String documentId,
  }) async {
    await api.deleteUri<Object?>(
      _scopeUri(
        routes.recordsDocumentDelete(
          profileId: _requiredId(profileId, 'profileId'),
          documentId: _requiredId(documentId, 'documentId'),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // File Upload
  // ─────────────────────────────────────────────

  Future<UploadedInsuranceDocumentFile> uploadDocumentFile({
    required String profileId,
    required PickedInsuranceDocumentFile file,
    required InsuranceDocumentType documentType,
    String? claimPackId,
  }) async {
    final pid = _requiredId(profileId, 'profileId');

    final uploadId = DocumentStoragePaths.newUploadId();

    final extension = DocumentStoragePaths.cleanExt(file.extension);

    final originalPath = DocumentStoragePaths.originalPath(
      tenantId: tenantId,
      appId: appId,
      profileId: pid,
      kind: 'insurance_documents',
      uploadId: uploadId,
      ext: extension,
    );

    final metadata = <String, String>{
      'upload_id': uploadId,
      'document_type': documentType.wire,
    };

    final claimId = _nullable(claimPackId);

    if (claimId != null) {
      metadata['claim_pack_id'] = claimId;
    }

    final uploaded = await _uploader.upload(
      profileId: pid,
      kind: 'insurance_documents',
      collectionUri: routes.recordsDocumentCreate(profileId: pid),
      storagePath: originalPath,
      file: DocumentUploadFile(fileName: file.fileName, bytes: file.bytes),
      metadata: metadata,
    );

    return UploadedInsuranceDocumentFile(
      fileName: uploaded.fileName,
      storagePath: uploaded.storagePath,
      originalStoragePath: uploaded.storagePath,
      thumbnailStoragePath: '',
      downloadUrl: uploaded.downloadUrl,
      contentType: uploaded.contentType,
      sizeBytes: uploaded.sizeBytes,
    );
  }

  Future<InsuranceDocument> uploadDocumentFileAndCreate({
    required String profileId,
    required PickedInsuranceDocumentFile file,
    required InsuranceDocumentType documentType,
    String? claimPackId,
    String? membershipId,
    String? payerContactId,
    String? payerDisplayName,
    String? title,
    String? notes,
    InsuranceDocumentStatus? status,
    bool? isActive,
  }) async {
    final uploaded = await uploadDocumentFile(
      profileId: profileId,
      file: file,
      documentType: documentType,
      claimPackId: claimPackId,
    );

    return create(
      profileId: profileId,
      input: uploaded.toCreateInput(
        claimPackId: claimPackId,
        documentType: documentType,
        membershipId: membershipId,
        payerContactId: payerContactId,
        payerDisplayName: payerDisplayName,
        title: title,
        notes: notes,
        status: status,
        isActive: isActive,
      ),
    );
  }

  /// Refresh on open. Private URLs expire after five minutes.
  Future<String> downloadUrl({
    required String profileId,
    required String storagePath,
  }) {
    return _uploader.downloadUrl(
      collectionUri: routes.recordsDocumentCreate(
        profileId: _requiredId(profileId, 'profileId'),
      ),
      storagePath: _requiredId(storagePath, 'storagePath'),
    );
  }

  // ─────────────────────────────────────────────
  // Response Parsing
  // ─────────────────────────────────────────────

  static InsuranceDocument _readDocument(Object? value) {
    return InsuranceDocument.fromJson(_asMap(value));
  }

  static List<InsuranceDocument> _readDocuments(Object? value) {
    return _asListOfMaps(
      value,
    ).map(InsuranceDocument.fromJson).toList(growable: false);
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
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, dynamic value) => MapEntry(key.toString(), value as Object?),
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
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
