// lib/core/api/shared/http_client.dart

import 'package:dio/dio.dart';

BaseOptions _defaults(String baseUrl, {Map<String, dynamic>? headers}) {
  return BaseOptions(
    baseUrl: baseUrl,
    headers: headers,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    responseType: ResponseType.json,
    contentType: Headers.jsonContentType,
    followRedirects: true,

    // Default: only success + redirects.
    // Handle expected 404s per request with Options(validateStatus: ...).
    validateStatus: (s) => s != null && s >= 200 && s < 400,
  );
}

Dio createHttpClient(String baseUrl, {Map<String, dynamic>? headers}) {
  return Dio(_defaults(baseUrl, headers: headers));
}
