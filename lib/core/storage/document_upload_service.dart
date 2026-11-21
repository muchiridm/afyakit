// lib/core/storage/document_upload_service.dart

import 'dart:typed_data';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/storage/document_storage_paths.dart';
import 'package:afyakit/core/storage/profile_storage_access.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DocumentUploadFile {
  const DocumentUploadFile({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;

  int get sizeBytes => bytes.lengthInBytes;
}

class UploadedDocumentFile {
  const UploadedDocumentFile({
    required this.fileName,
    required this.storagePath,
    required this.contentType,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  final String fileName;
  final String storagePath;
  final String contentType;
  final int sizeBytes;

  /// Short-lived private URL. Never persist this.
  final String downloadUrl;
}

/// Shared upload infrastructure for profile-associated documents.
///
/// Handles:
/// - File validation
/// - Storage path verification
/// - Backend-authorised upload metadata
/// - Firebase Storage uploads
/// - Private download URLs
///
/// Document record creation remains the responsibility
/// of the calling domain service.
class DocumentUploadService {
  const DocumentUploadService({
    required this.api,
    required this.tenantId,
    required this.appId,
    FirebaseStorage? storage,
  }) : _storage = storage;

  final AfyaKitClient api;
  final String tenantId;
  final String appId;
  final FirebaseStorage? _storage;

  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  Future<UploadedDocumentFile> upload({
    required String profileId,
    required String kind,
    required Uri collectionUri,
    required String storagePath,
    required DocumentUploadFile file,
    Map<String, String> metadata = const {},
  }) async {
    // Validate file size.
    if (file.sizeBytes == 0 ||
        file.sizeBytes > DocumentStoragePaths.maxFileBytes) {
      throw ArgumentError('Choose a non-empty file no larger than 20 MiB');
    }

    // Validate extension and resolve MIME type.
    final dot = file.fileName.lastIndexOf('.');

    if (dot <= 0 || dot == file.fileName.length - 1) {
      throw ArgumentError.value(
        file.fileName,
        'fileName',
        'A supported file extension is required',
      );
    }

    final extension = DocumentStoragePaths.cleanExt(
      file.fileName.substring(dot + 1),
    );

    final contentType = DocumentStoragePaths.contentTypeForExt(extension);

    // Validate storage scope.
    if (!DocumentStoragePaths.belongsToScope(
      storagePath: storagePath,
      tenantId: tenantId,
      appId: appId,
      profileId: profileId,
      kind: kind,
    )) {
      throw ArgumentError.value(
        storagePath,
        'storagePath',
        'Storage path does not belong to this profile and app',
      );
    }

    // Request authorisation context from backend.
    final context = await ProfileStorageAccess.uploadMetadata(
      api: api,
      collectionUri: collectionUri,
      tenantId: tenantId,
      profileId: profileId,
      appId: appId,
    );

    // Authoritative values override caller metadata.
    final customMetadata = <String, String>{
      ...metadata,
      ...context,
      'tenant_id': tenantId,
      'app_id': appId,
      'profile_id': profileId,
      'original_file_name': file.fileName,
    };

    final reference = storage.ref(storagePath);

    await reference.putData(
      file.bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: customMetadata,
      ),
    );

    // Retrieve backend-authorised private download URL.
    final url = await ProfileStorageAccess.downloadUrl(
      api: api,
      appId: appId,
      collectionUri: collectionUri,
      storagePath: storagePath,
    );

    return UploadedDocumentFile(
      fileName: file.fileName,
      storagePath: storagePath,
      contentType: contentType,
      sizeBytes: file.sizeBytes,
      downloadUrl: url,
    );
  }

  /// Retrieve a fresh private download URL.
  Future<String> downloadUrl({
    required Uri collectionUri,
    required String storagePath,
  }) {
    final path = storagePath.trim();

    if (path.isEmpty) {
      throw ArgumentError.value(
        storagePath,
        'storagePath',
        'Storage path is required',
      );
    }

    return ProfileStorageAccess.downloadUrl(
      api: api,
      appId: appId,
      collectionUri: collectionUri,
      storagePath: path,
    );
  }
}
