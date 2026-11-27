// lib/core/notifications/foreground_notification/foreground_notification_web.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

Future<void> showForegroundNotification(RemoteMessage message) async {
  try {
    if (web.Notification.permission != 'granted') {
      debugPrint(
        '🔕 Foreground web notification skipped: '
        'browser permission=${web.Notification.permission}',
      );

      return;
    }

    final type = message.data['type'];
    if (type != 'chat_message' && type != 'activity') return;
    web.Notification(
      'AfyaKit',
      web.NotificationOptions(
        body: type == 'chat_message'
            ? 'You have a new message.'
            : 'You have a new update.',
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
      ),
    );
  } catch (_) {
    debugPrint('[notifications] display-unavailable');
  }
}
