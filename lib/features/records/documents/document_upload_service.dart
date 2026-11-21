import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const maxDocumentBytes = 20 * 1024 * 1024;

class PickedDocumentFile {
  const PickedDocumentFile({
    required this.fileName,
    required this.extension,
    required this.bytes,
  });
  final String fileName, extension;
  final Uint8List bytes;
  int get sizeBytes => bytes.lengthInBytes;
  String get contentType => switch (extension.toLowerCase()) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => throw ArgumentError('Unsupported file type'),
  };
  void validate() {
    if (sizeBytes == 0 || sizeBytes > maxDocumentBytes) {
      throw ArgumentError('Select a file between 1 byte and 20 MiB');
    }
    if (fileName.trim().isEmpty ||
        fileName.length > 255 ||
        fileName == '.' ||
        fileName == '..' ||
        fileName.contains('/') ||
        fileName.contains('\\') ||
        fileName.codeUnits.any((c) => c < 32 || c == 127)) {
      throw ArgumentError('Invalid file name');
    }
    // Force MIME validation before allocating a reservation.
    if (contentType.isEmpty) throw ArgumentError('Invalid content type');
  }
}

class DocumentUploadReservation {
  const DocumentUploadReservation({
    required this.documentId,
    required this.uri,
    required this.headers,
    required this.finalizeBy,
  });
  final String documentId;
  final Uri uri;
  final Map<String, String> headers;
  final DateTime finalizeBy;
  factory DocumentUploadReservation.fromJson(Map<String, Object?> json) {
    final uri = Uri.parse(json['upload_url'] as String);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        json['upload_method'] != 'PUT') {
      throw const FormatException('Invalid signed upload reservation');
    }
    return DocumentUploadReservation(
      documentId: json['document_id'] as String,
      uri: uri,
      headers: Map<String, String>.from(json['upload_headers'] as Map),
      finalizeBy: DateTime.parse(json['finalize_by'] as String),
    );
  }
}

/// Isolated HTTP client: never forwards AfyaKit headers or interceptors.
class SignedDocumentUploadService {
  const SignedDocumentUploadService();
  Future<void> upload(
    DocumentUploadReservation reservation,
    PickedDocumentFile file,
  ) async {
    final headers = Map<String, String>.from(reservation.headers);
    if (headers['content-type'] != file.contentType ||
        headers['content-length'] != '${file.sizeBytes}' ||
        headers['x-goog-if-generation-match'] != '0') {
      throw StateError('Signed upload requirements do not match the file');
    }
    // Browsers set Content-Length themselves; native clients may set it.
    if (kIsWeb) headers.remove('content-length');
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 3),
      ),
    );
    try {
      await dio.putUri<void>(
        reservation.uri,
        data: file.bytes,
        options: Options(
          headers: headers,
          contentType: file.contentType,
          followRedirects: false,
          responseType: ResponseType.plain,
        ),
      );
    } on DioException catch (e) {
      // Never expose signed URLs or storage request bodies in error messages.
      throw StateError(
        'Document transfer failed (HTTP ${e.response?.statusCode ?? 'unavailable'})',
      );
    } finally {
      dio.close(force: true);
    }
  }
}
