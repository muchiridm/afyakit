import 'package:dio/dio.dart';

BaseOptions _defaults(String baseUrl, {Map<String, dynamic>? headers}) =>
    BaseOptions(
      baseUrl: baseUrl,
      headers: headers,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
      contentType: 'application/json',
      followRedirects: true,
      validateStatus: (s) => s != null && (s >= 200 && s < 400 || s == 404),
    );

Dio createHttpClient(String baseUrl, {Map<String, dynamic>? headers}) =>
    Dio(_defaults(baseUrl, headers: headers));
