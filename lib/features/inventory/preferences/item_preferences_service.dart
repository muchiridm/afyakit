import 'package:dio/dio.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';

/// Backend response for every preference operation is a raw JSON string list.
/// POST/DELETE take {value}; PUT takes a raw JSON array (not {values: ...}).
class ItemPreferencesService {
  const ItemPreferencesService({required this.dio, required this.routes});

  final Dio dio;
  final AfyaKitRoutes routes;

  Uri _uri(String itemType, String field) =>
      routes.preferenceField(itemType, field);

  List<String> _read(dynamic data) {
    if (data is! List) {
      throw const FormatException('Invalid preference response: expected list');
    }
    return data.map((value) => value as String).toList(growable: false);
  }

  Future<List<String>> get(String itemType, String field) async =>
      _read((await dio.getUri(_uri(itemType, field))).data);

  Future<List<String>> add(String itemType, String field, String value) async =>
      _read((await dio.postUri(
        _uri(itemType, field),
        data: {'value': value.trim()},
      )).data);

  Future<List<String>> remove(String itemType, String field, String value) async =>
      _read((await dio.deleteUri(
        _uri(itemType, field),
        data: {'value': value},
      )).data);

  Future<List<String>> replace(
    String itemType,
    String field,
    List<String> values,
  ) async => _read((await dio.putUri(
    _uri(itemType, field),
    data: values.map((value) => value.trim()).where((v) => v.isNotEmpty).toSet().toList(),
  )).data);
}
