import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'inventory_import.dart';

/// Uses the authenticated AfyaKit Dio client (including its application scope).
class InventoryImportService {
  const InventoryImportService({required this.dio, required this.routes});
  final Dio dio;
  final AfyaKitRoutes routes;

  Future<Uint8List> template(String typeId) async {
    final response = await dio.getUri<List<int>>(
      routes.importTemplate(typeId),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const <int>[]);
  }

  Future<InventoryImportResult> validate({
    required String typeId,
    required String filename,
    required Uint8List bytes,
  }) => _upload(typeId: typeId, filename: filename, bytes: bytes, persist: false);

  Future<InventoryImportResult> persist({
    required String typeId,
    required String filename,
    required Uint8List bytes,
  }) => _upload(typeId: typeId, filename: filename, bytes: bytes, persist: true);

  Future<InventoryImportResult> _upload({
    required String typeId,
    required String filename,
    required Uint8List bytes,
    required bool persist,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('The selected file is empty.');
    final response = await dio.postUri<Map<String, dynamic>>(
      routes.importInventory(type: typeId, dryRun: !persist, persist: persist),
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    return InventoryImportResult.fromJson(
      Map<String, dynamic>.from(response.data ?? const {}),
    );
  }
}
