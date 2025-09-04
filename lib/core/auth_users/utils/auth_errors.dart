import 'package:dio/dio.dart';

bool isSoftAuthError(DioException e) {
  final sc = e.response?.statusCode ?? 0;
  return sc == 401 || sc == 403;
}
