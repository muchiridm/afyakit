import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:afyakit/core/api/afyakit/client.dart';

class PrivateFile {
  const PrivateFile(
    this.bytes,
    this.contentType,
    this.fileName,
    this.isCurrent,
  );
  final bool Function() isCurrent;
  final Uint8List bytes;
  final String contentType, fileName;
}

Future<PrivateFile> downloadPrivateFile(
  AfyaKitClient api,
  Uri uri,
  String name,
  bool Function() current,
) async {
  if (!current()) throw StateError('File session changed');
  try {
    final response = await api.postUri<List<int>>(
      uri,
      data: <String, Object?>{},
      options: Options(
        responseType: ResponseType.bytes,
        extra: {'sensitiveResponse': true},
      ),
    );
    if (!current()) throw StateError('File session changed');
    final type = response.headers.value('content-type')?.split(';').first;
    final bytes = response.data;
    if (![
          'application/pdf',
          'image/jpeg',
          'image/png',
          'image/webp',
        ].contains(type) ||
        bytes == null ||
        bytes.isEmpty ||
        bytes.length > 20 * 1024 * 1024) {
      throw StateError('Invalid private file response');
    }
    return PrivateFile(Uint8List.fromList(bytes), type!, name, current);
  } catch (_) {
    throw StateError(
      'Private file unavailable; access or file verification may be required.',
    );
  }
}
