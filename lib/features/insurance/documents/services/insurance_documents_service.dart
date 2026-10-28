// lib/features/insurance/documents/services/insurance_documents_service.dart

import 'dart:typed_data';
import 'package:afyakit/core/storage/profile_storage_access.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/features/insurance/documents/models/insurance_document.dart';
import 'package:afyakit/features/insurance/documents/services/insurance_document_storage_paths.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/storage/document_app_provider.dart';

final insuranceDocumentsServiceProvider =
    FutureProvider<InsuranceDocumentsService>((ref) async {
      final String tenantId = ref.watch(tenantIdProvider);
      final appId = ref.watch(documentAppIdProvider);
      final AfyaKitRoutes routes = AfyaKitRoutes(tenantId);
      final AfyaKitClient api = await ref.watch(
        afyakitClientFutureProvider.future,
      );

      return InsuranceDocumentsService(
        appId: appId,
        tenantId: tenantId,
        api: api,
        routes: routes,
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
      // Neither an ungenerated thumbnail nor a short-lived URL is persisted.
      thumbnailStoragePath: thumbnailStoragePath.isEmpty ? null : thumbnailStoragePath,
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
  Uri _scopeUri(Uri uri) => ProfileStorageAccess.scopedUri(uri, appId);

  final AfyaKitClient api;
  final AfyaKitRoutes routes;
  final FirebaseStorage? _storage;

  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

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
    final Uri uri = routes.insuranceDocumentsList(
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
    final Map<String, Object?> body = _asMap(response.data);

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
    final String cleanProfileId = _requiredId(profileId, 'profileId');

    final Uri uri = routes.insuranceDocumentsListForProfile(
      profileId: cleanProfileId,
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
    final Map<String, Object?> body = _asMap(response.data);

    return _readDocuments(body['documents']);
  }

  Future<InsuranceDocument> get({
    required String profileId,
    required String documentId,
  }) async {
    final String cleanProfileId = _requiredId(profileId, 'profileId');
    final String cleanDocumentId = _requiredId(documentId, 'documentId');

    final response = await api.getUri<Object?>(_scopeUri(routes.insuranceDocumentGet(
        profileId: cleanProfileId,
        documentId: cleanDocumentId,
      )),
    );

    final Map<String, Object?> body = _asMap(response.data);
    return _readDocument(body['document']);
  }

  Future<InsuranceDocument> create({
    required String profileId,
    required InsuranceDocumentCreateInput input,
  }) async {
    final String cleanProfileId = _requiredId(profileId, 'profileId');

    final response = await api.postUri<Object?>(_scopeUri(routes.insuranceDocumentCreate(profileId: cleanProfileId)),
      data: input.toJson(),
    );

    final Map<String, Object?> body = _asMap(response.data);
    return _readDocument(body['document']);
  }

  Future<InsuranceDocument> update({
    required String profileId,
    required String documentId,
    required InsuranceDocumentUpdateInput input,
  }) async {
    final String cleanProfileId = _requiredId(profileId, 'profileId');
    final String cleanDocumentId = _requiredId(documentId, 'documentId');

    final response = await api.putUri<Object?>(_scopeUri(routes.insuranceDocumentUpdate(
        profileId: cleanProfileId,
        documentId: cleanDocumentId,
      )),
      data: input.toJson(),
    );

    final Map<String, Object?> body = _asMap(response.data);
    return _readDocument(body['document']);
  }

  Future<void> delete({
    required String profileId,
    required String documentId,
  }) async {
    final String cleanProfileId = _requiredId(profileId, 'profileId');
    final String cleanDocumentId = _requiredId(documentId, 'documentId');

    await api.deleteUri<Object?>(_scopeUri(routes.insuranceDocumentDelete(
        profileId: cleanProfileId,
        documentId: cleanDocumentId,
      )),
    );
  }

  Future<UploadedInsuranceDocumentFile> uploadDocumentFile({
    required String profileId,
    required PickedInsuranceDocumentFile file,
    required InsuranceDocumentType documentType,
    String? claimPackId,
  }) async {
    final String cleanTenantId = _requiredId(tenantId, 'tenantId');
    final String cleanProfileId = _requiredId(profileId, 'profileId');

    if (file.sizeBytes == 0 || file.sizeBytes > InsuranceDocumentStoragePaths.maxFileBytes) {
      throw ArgumentError('Choose a non-empty file no larger than 20 MiB');
    }

    final String uploadId = InsuranceDocumentStoragePaths.newUploadId();
    final String ext = InsuranceDocumentStoragePaths.cleanExt(file.extension);
    final String contentType = InsuranceDocumentStoragePaths.contentTypeForExt(
      ext,
    );

    final String originalPath = InsuranceDocumentStoragePaths.originalPath(
      tenantId: cleanTenantId,
      appId: appId,
      profileId: cleanProfileId,
      uploadId: uploadId,
      ext: ext,
    );

    final context = await ProfileStorageAccess.uploadMetadata(
      api: api,
      collectionUri: routes.insuranceDocumentCreate(profileId: cleanProfileId),
      tenantId: cleanTenantId,
      profileId: cleanProfileId,
      appId: appId,
    );

    final Map<String, String> customMetadata = <String, String>{
      ...context,
      'tenant_id': cleanTenantId,
      'profile_id': cleanProfileId,
      'upload_id': uploadId,
      'document_type': documentType.wire,
      'original_file_name': file.fileName,
    };

    final String? cleanClaimPackId = _nullable(claimPackId);
    if (cleanClaimPackId != null) {
      customMetadata['claim_pack_id'] = cleanClaimPackId;
    }

    final SettableMetadata metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: customMetadata,
    );

    final Reference ref = storage.ref(originalPath);

    await ref.putData(file.bytes, metadata);

    final String downloadUrl = await this.downloadUrl(
      profileId: cleanProfileId, storagePath: originalPath,
    );

    return UploadedInsuranceDocumentFile(
      fileName: file.fileName,
      storagePath: originalPath,
      originalStoragePath: originalPath,
      thumbnailStoragePath: '',
      downloadUrl: downloadUrl,
      contentType: contentType,
      sizeBytes: file.sizeBytes,
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
    final UploadedInsuranceDocumentFile uploaded = await uploadDocumentFile(
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

  /// Refresh on open; returned URLs expire after five minutes.
  Future<String> downloadUrl({
    required String profileId,
    required String storagePath,
  }) => ProfileStorageAccess.downloadUrl(
    appId: appId,
    api: api,
    collectionUri: routes.insuranceDocumentCreate(
      profileId: _requiredId(profileId, 'profileId'),
    ),
    storagePath: _requiredId(storagePath, 'storagePath'),
  );

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
