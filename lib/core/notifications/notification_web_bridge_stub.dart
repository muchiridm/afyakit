void installNotificationBridge(
  String? Function() context,
  Future<bool> Function(Map<String, dynamic>) validate,
) {}
Future<bool> notificationTabsAgree(String context) async => true;
