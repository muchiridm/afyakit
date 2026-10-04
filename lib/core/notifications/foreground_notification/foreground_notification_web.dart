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

    final String title = _notificationTitle(message);
    final String body = _notificationBody(message);
    final String conversationId = _value(message.data['conversationId']);

    web.Notification(
      title,
      web.NotificationOptions(
        body: body,
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        tag: conversationId.isEmpty ? 'afyakit_chat' : 'chat_$conversationId',
      ),
    );

    debugPrint(
      '🔔 Foreground web notification shown '
      'conversationId=$conversationId',
    );
  } catch (error, stackTrace) {
    debugPrint('❌ Failed to show foreground web notification: $error');

    debugPrintStack(stackTrace: stackTrace);
  }
}

String _notificationTitle(RemoteMessage message) {
  final String title = _value(message.notification?.title);

  if (title.isNotEmpty) {
    return title;
  }

  final String dataTitle = _value(message.data['title']);

  if (dataTitle.isNotEmpty) {
    return dataTitle;
  }

  return 'DawaPap';
}

String _notificationBody(RemoteMessage message) {
  final String body = _value(message.notification?.body);

  if (body.isNotEmpty) {
    return body;
  }

  final String dataBody = _value(message.data['body']);

  if (dataBody.isNotEmpty) {
    return dataBody;
  }

  return 'You have a new message.';
}

String _value(Object? value) {
  return value?.toString().trim() ?? '';
}
