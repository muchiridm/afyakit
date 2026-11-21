import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'document_model.dart';
import 'document_upload_service.dart';

final documentsServiceProvider = FutureProvider<DocumentsService>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final appId = ref.watch(appIdProvider);
  final routes = ref.watch(afyakitRoutesProvider);
  final api = await ref.watch(afyakitClientFutureProvider.future);
  return DocumentsService(
    api: api,
    routes: routes,
    tenantId: tenantId,
    appId: appId,
  );
});

class DocumentsService {
  const DocumentsService({
    required this.api,
    required this.routes,
    required this.tenantId,
    required this.appId,
    this.uploader = const SignedDocumentUploadService(),
  });
  final AfyaKitClient api;
  final AfyaKitRoutes routes;
  final String tenantId, appId;
  final SignedDocumentUploadService uploader;

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid Documents API response');
    }
    return Map<String, Object?>.from(value);
  }

  Document _document(Object? value, {String? profileId, String? documentId}) {
    final doc = Document.fromJson(_map(value));
    if (doc.tenantId != tenantId ||
        doc.appId != appId ||
        (profileId != null && doc.profileId != profileId) ||
        (documentId != null && doc.documentId != documentId)) {
      throw StateError('Document scope mismatch');
    }
    return doc;
  }

  Future<List<Document>> list({
    required String profileId,
    DocumentType? documentType,
    DocumentStatus? status,
    bool? isActive,
    String? search,
    int page = 1,
    int perPage = 50,
  }) async {
    final res = await api.getUri<Object?>(
      routes.recordsDocumentsList(
        profileId: profileId,
        documentType: documentType?.wire,
        status: status?.wire,
        isActive: isActive,
        search: search,
        page: page,
        perPage: perPage,
      ),
    );
    final raw = _map(res.data)['documents'];
    if (raw is! List) throw const FormatException('Missing documents array');
    return raw
        .map((e) => _document(e, profileId: profileId))
        .toList(growable: false);
  }

  Future<Document> get(String id, {required String profileId}) async {
    final res = await api.getUri<Object?>(routes.recordsDocumentById(id));
    return _document(
      _map(res.data)['document'],
      profileId: profileId,
      documentId: id,
    );
  }

  Future<DocumentUploadReservation> allocate({
    required String profileId,
    required PickedDocumentFile file,
  }) async {
    file.validate();
    final res = await api.postUri<Object?>(
      routes.recordsDocumentStorageAccess(),
      data: {
        'profile_id': profileId,
        'file_name': file.fileName,
        'content_type': file.contentType,
        'size_bytes': file.sizeBytes,
      },
    );
    final raw = _map(_map(res.data)['storage_access']);
    if (raw['tenant_id'] != tenantId ||
        raw['app_id'] != appId ||
        raw['profile_id'] != profileId) {
      throw StateError('Upload reservation scope mismatch');
    }
    return DocumentUploadReservation.fromJson(raw);
  }

  Future<Document> create({
    required String profileId,
    required DocumentCreateInput input,
  }) async {
    final res = await api.postUri<Object?>(
      routes.recordsDocuments(),
      data: input.toJson(),
    );
    return _document(
      _map(res.data)['document'],
      profileId: profileId,
      documentId: input.documentId,
    );
  }

  Future<Document> upload({
    required String profileId,
    required PickedDocumentFile file,
    required DocumentType documentType,
    String? title,
    String? notes,
    DocumentVisibility? visibility,
  }) async {
    final reservation = await allocate(profileId: profileId, file: file);
    await uploader.upload(reservation, file);
    final input = DocumentCreateInput(
      documentId: reservation.documentId,
      documentType: documentType,
      title: title,
      notes: notes,
      visibility: visibility,
    );
    try {
      return await create(profileId: profileId, input: input);
    } catch (_) {
      // Keep the document ID so the caller can retry finalization without uploading again.
      throw DocumentFinalizationException(profileId, input);
    }
  }

  Future<Document> update(Document document, DocumentUpdateInput input) async {
    _assertScope(document);
    final data = input.toJson();
    if (data.isEmpty) throw ArgumentError('No metadata changes supplied');
    final res = await api.patchUri<Object?>(
      routes.recordsDocumentById(document.documentId),
      data: data,
    );
    return _document(
      _map(res.data)['document'],
      profileId: document.profileId,
      documentId: document.documentId,
    );
  }

  Future<void> archive(Document document) async {
    _assertScope(document);
    final res = await api.deleteUri<Object?>(
      routes.recordsDocumentById(document.documentId),
    );
    if (_map(res.data)['ok'] != true) {
      throw StateError('Archive was not confirmed');
    }
  }

  Future<Uri> download(Document document) async {
    _assertScope(document);
    final res = await api.postUri<Object?>(
      routes.recordsDocumentStorageDownload(document.documentId),
      data: <String, Object?>{},
    );
    final url = Uri.parse(_map(res.data)['download_url'] as String);
    if (url.scheme != 'https' || url.host.isEmpty || url.userInfo.isNotEmpty) {
      throw const FormatException('Invalid document download URL');
    }
    return url;
  }

  void _assertScope(Document doc) {
    if (doc.tenantId != tenantId || doc.appId != appId) {
      throw StateError('Document scope mismatch');
    }
  }
}

class DocumentFinalizationException implements Exception {
  const DocumentFinalizationException(this.profileId, this.input);
  final String profileId;
  final DocumentCreateInput input;
  @override
  String toString() =>
      'File uploaded, but document finalization failed. Retry finalization before uploading again.';
}
