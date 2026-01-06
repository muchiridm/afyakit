// lib/core/api/shared/http_client.dart
import 'package:dio/dio.dart';

/// Single source of truth for API timeouts.
/// Keep connect/receive/send aligned unless you have a reason not to.
const kApiConnectTimeout = Duration(seconds: 45);
const kApiReceiveTimeout = Duration(seconds: 45);
const kApiSendTimeout = Duration(seconds: 45);

BaseOptions _defaults(
  String baseUrl, {
  Map<String, dynamic>? headers,
  Duration? connectTimeout,
  Duration? receiveTimeout,
  Duration? sendTimeout,
}) {
  return BaseOptions(
    baseUrl: baseUrl,
    headers: headers,
    connectTimeout: connectTimeout ?? kApiConnectTimeout,
    receiveTimeout: receiveTimeout ?? kApiReceiveTimeout,
    sendTimeout: sendTimeout ?? kApiSendTimeout,
    responseType: ResponseType.json,
    contentType: Headers.jsonContentType,
    followRedirects: true,

    // Default: only success + redirects.
    validateStatus: (s) => s != null && s >= 200 && s < 400,
  );
}

Dio createHttpClient(
  String baseUrl, {
  Map<String, dynamic>? headers,
  Duration? connectTimeout,
  Duration? receiveTimeout,
  Duration? sendTimeout,
}) {
  return Dio(
    _defaults(
      baseUrl,
      headers: headers,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
    ),
  );
}
