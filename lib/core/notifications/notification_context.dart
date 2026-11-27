import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

bool matchesNotificationContext(
  Map<String, dynamic> data,
  AuthUser user,
  String appId, {
  required String? authenticatedUid,
}) {
  return authenticatedUid == user.uid &&
      user.uid.isNotEmpty &&
      appId.isNotEmpty &&
      user.tenantId.isNotEmpty &&
      user.status.isActive &&
      user.membershipForApp(appId)?.isActive == true &&
      data['tenantId'] == user.tenantId &&
      data['appId'] == appId &&
      data['recipientUid'] == user.uid &&
      (data['type'] == 'chat_message' || data['type'] == 'activity');
}
