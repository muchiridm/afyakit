import 'package:dio/dio.dart';
import 'package:afyakit/api/shared/http_client.dart';
import 'package:afyakit/api/shared/interceptors.dart';

class DawaIndexClient {
  final Dio dio;
  DawaIndexClient(this.dio);

  static Future<DawaIndexClient> create({
    required String baseUrl,
    String? apiKey,
  }) async {
    final headers = <String, dynamic>{
      if ((apiKey ?? '').isNotEmpty) 'x-api-key': apiKey!,
    };
    final http = createHttpClient(baseUrl, headers: headers);
    http.interceptors.add(requestIdAndTiming());
    return DawaIndexClient(http);
  }
}
