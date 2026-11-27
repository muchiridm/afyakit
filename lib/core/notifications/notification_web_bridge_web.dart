import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void installNotificationBridge(
  String? Function() context,
  Future<bool> Function(Map<String, dynamic>) validate,
) {
  web.window.navigator.serviceWorker.addEventListener(
    'message',
    ((web.MessageEvent event) {
      final data = event.data.dartify();
      if (data is! Map || event.ports.length == 0) return;
      final port = event.ports[0];
      if (data['type'] == 'notification-context') {
        port.postMessage(context()?.toJS);
      } else if (data['type'] == 'notification-validate' &&
          data['payload'] is Map) {
        unawaited(() async {
          bool allowed = false;
          try {
            allowed = await validate(
              Map<String, dynamic>.from(data['payload'] as Map),
            );
          } catch (_) {}
          port.postMessage(allowed.toJS);
        }());
      }
    }).toJS,
  );
}

Future<bool> notificationTabsAgree(String context) async {
  try {
    final registration = await web.window.navigator.serviceWorker
        .getRegistration('/firebase-cloud-messaging-push-scope')
        .toDart
        .timeout(const Duration(seconds: 3));
    final worker = registration?.active;
    if (worker == null) return false;
    final channel = web.MessageChannel();
    final result = Completer<bool>();
    channel.port1.onmessage = ((web.MessageEvent event) {
      if (!result.isCompleted) result.complete(event.data.dartify() == true);
    }).toJS;
    worker.postMessage(
      {'type': 'notification-context-check', 'context': context}.jsify(),
      [channel.port2].toJS,
    );
    try {
      return await result.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
    } finally {
      channel.port1.close();
      channel.port2.close();
    }
  } catch (_) {
    return false;
  }
}
