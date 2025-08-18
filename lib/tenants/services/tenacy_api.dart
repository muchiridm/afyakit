// lib/hq/tenants/services/tenancy_api.dart
import 'package:dio/dio.dart';
import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';

class InviteResult {
  final String uid;
  final bool authCreated;
  final bool membershipCreated;
  InviteResult({
    required this.uid,
    required this.authCreated,
    required this.membershipCreated,
  });

  factory InviteResult.fromJson(Map<String, dynamic> j) => InviteResult(
    uid: (j['uid'] ?? '').toString(),
    authCreated: j['authCreated'] == true,
    membershipCreated: j['membershipCreated'] == true,
  );
}

class TenancyApi {
  TenancyApi({required this.client, required this.routes});
  final ApiClient client; // baseUrl already = https://.../api/<tenantId>
  final ApiRoutes routes; // knows the same tenantId
  Dio get _dio => client.dio;

  Future<InviteResult> invite({
    required String email,
    String role = 'staff', // 'owner' | 'admin' | 'manager' | 'staff' | 'client'
  }) async {
    final payload = {'email': EmailHelper.normalize(email), 'role': role};
    final res = await _dio.postUri(routes.inviteToTenant(), data: payload);
    if ((res.statusCode ?? 0) ~/ 100 != 2) {
      final reason =
          (res.data is Map ? (res.data as Map)['error'] : null) ?? 'Unknown';
      throw Exception('Invite failed: $reason');
    }
    return InviteResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> revoke({required String uid}) async {
    final r = await _dio.deleteUri(routes.revokeFromTenant(uid));
    final ok = (r.statusCode == 204) || ((r.statusCode ?? 0) ~/ 100 == 2);
    if (!ok) {
      final reason =
          (r.data is Map ? (r.data as Map)['error'] : null) ?? 'Unknown';
      throw Exception('Revoke failed: $reason');
    }
  }
}
