import 'package:afyakit/core/api/afyakit/client.dart';

/// Uses existing collection URIs so no route-provider changes are required.
final class ProfileStorageAccess {
  const ProfileStorageAccess._();

  static Uri scopedUri(Uri uri, String appId) {
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(appId)) {
      throw ArgumentError('Active appId is required');
    }
    return uri.replace(queryParameters: {...uri.queryParameters, 'appId': appId});
  }

  static Uri _endpoint(Uri collection, String suffix) => collection.replace(
    path: '${collection.path.replaceFirst(RegExp(r'/$'), '')}/$suffix',
    query: '',
    fragment: '',
  );

  static Future<Map<String, String>> uploadMetadata({
    required AfyaKitClient api,
    required Uri collectionUri,
    required String tenantId,
    required String profileId,
    required String appId,
  }) async {
    final response = await api.postUri<Object?>(
      scopedUri(_endpoint(collectionUri, 'storage-access'), appId),
      data: <String, Object?>{},
    );
    final body = response.data;
    if (body is! Map || body['storage_access'] is! Map) {
      throw const FormatException('Missing storage access context');
    }
    final context = body['storage_access'] as Map;
    if (context['tenant_id'] != tenantId ||
        context['profile_id'] != profileId ||
        context['app_id'] != appId ||
        context['uploaded_by_uid'] is! String) {
      throw StateError('Storage scope does not match the active API session');
    }
    return context.map<String, String>(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  static Future<String> downloadUrl({
    required AfyaKitClient api,
    required Uri collectionUri,
    required String storagePath,
    required String appId,
  }) async {
    final response = await api.postUri<Object?>(
      scopedUri(_endpoint(collectionUri, 'storage-download'), appId),
      data: <String, Object?>{'storage_path': storagePath},
    );
    final body = response.data;
    if (body is! Map || body['download_url'] is! String) {
      throw const FormatException('Missing download URL');
    }
    return body['download_url'] as String;
  }
}
