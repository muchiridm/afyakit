// lib/core/notifications/foreground_notification/foreground_notification_stub.dart

import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> showForegroundNotification(RemoteMessage message) async {
  // Native foreground notification presentation is handled separately.
  //
  // Android/iOS behavior remains unchanged.
}
