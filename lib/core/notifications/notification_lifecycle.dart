import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'notification_context.dart';
import 'notification_service.dart';
import 'notification_web_bridge.dart';
import 'foreground_notification/foreground_notification.dart';

/// A context generation fences every asynchronous result, including disposal/logout.
class NotificationEpoch {
  int _value = 0;
  int advance() => ++_value;
  bool current(int value) => value == _value;
}

class NotificationLifecycle {
  NotificationLifecycle._()
    : currentUid = (() => FirebaseAuth.instance.currentUser?.uid),
      createService = NotificationService.create,
      obtainToken = _obtainToken,
      tabsAgree = notificationTabsAgree,
      testing = false;

  @visibleForTesting
  NotificationLifecycle.testing({
    required this.currentUid,
    required this.createService,
    required this.obtainToken,
    required this.tabsAgree,
  }) : testing = true;
  final String? Function() currentUid;
  final Future<NotificationService> Function(String, String, String)
  createService;
  final Future<String?> Function() obtainToken;
  final Future<bool> Function(String) tabsAgree;
  final bool testing;
  @visibleForTesting
  Future<void> refresh() => _refresh();
  @visibleForTesting
  void receiveProof(Map<String, dynamic> data) {
    if (data['type'] == 'notification_possession' &&
        data['challengeId'] == _challenge &&
        _proof != null &&
        !_proof!.isCompleted &&
        data['proof'] is String) {
      _proof!.complete(data['proof']);
    }
  }

  static Future<String?> _obtainToken() async {
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      return null;
    }
    const vapid = String.fromEnvironment('FCM_WEB_VAPID_KEY');
    if (kIsWeb && vapid.isEmpty) return null;
    return messaging.getToken(vapidKey: kIsWeb ? vapid : null);
  }

  static final instance = NotificationLifecycle._();
  final epoch = NotificationEpoch();
  AuthUser? _user;
  String? _app;
  NotificationService? _service;
  Map<String, dynamic>? _registration;
  String? _token;
  String? _challenge;
  Completer<String>? _proof;
  bool _installed = false;
  bool _busy = false;
  bool _signingOut = false;
  Object? _attachment;
  String? get context =>
      _user == null ? null : jsonEncode([_user!.tenantId, _app, _user!.uid]);

  void attach(Object attachment, AuthUser user, String app) {
    if (_signingOut) return;
    _install();
    final changed =
        _user?.uid != user.uid ||
        _user?.tenantId != user.tenantId ||
        _app != app;
    if (changed) clear();
    _attachment = attachment;
    _user = user;
    _app = app;
    if (!user.status.isActive || user.membershipForApp(app)?.isActive != true) {
      clear();
      return;
    }
    unawaited(_refresh());
  }

  void detach(Object attachment) {
    if (identical(_attachment, attachment)) clear();
  }

  void _install() {
    if (_installed || testing) return;
    _installed = true;
    FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      if (data['type'] == 'notification_possession') {
        receiveProof(data);
        return;
      }
      unawaited(() async {
        if (context != null &&
            await notificationTabsAgree(context!) &&
            await validateDisplay(data)) {
          await showForegroundNotification(message);
        }
      }());
    });
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (_) => unawaited(_refresh()),
      onError: (Object _) {},
    );
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (_user != null && user?.uid != _user!.uid) clear();
    });
    installNotificationBridge(
      () => currentUid() == _user?.uid ? context : null,
      validateDisplay,
    );
    Timer.periodic(const Duration(minutes: 1), (_) => unawaited(_refresh()));
  }

  // Synchronous local invalidation; network cleanup is bounded and best-effort.
  Future<void> clear() async {
    epoch.advance();
    final service = _service;
    final registration = _registration;
    final challenge = _challenge;
    _user = null;
    _app = null;
    _attachment = null;
    _service = null;
    _registration = null;
    _token = null;
    _challenge = null;
    if (_proof != null && !_proof!.isCompleted) _proof!.complete('');
    _proof = null;
    try {
      await Future.wait([
        if (service != null && challenge != null) service.cancel(challenge),
        if (service != null && registration != null)
          service.revoke(registration),
      ]).timeout(const Duration(seconds: 2));
    } catch (_) {
      /* Lease and send-time authorization remain authoritative. */
    }
  }

  static Future<void> signOut(FirebaseAuth auth) async {
    final uid = auth.currentUser?.uid;
    instance._signingOut = true;
    final cleanup = instance.clear();
    try {
      try {
        await Future.wait([
          cleanup,
          FirebaseMessaging.instance.deleteToken(),
        ]).timeout(const Duration(seconds: 2));
      } catch (_) {}
      if (auth.currentUser?.uid == uid) await auth.signOut();
    } finally {
      instance._signingOut = false;
    }
  }

  Future<void> _refresh() async {
    if (_busy || _user == null) return;
    _busy = true;
    final user = _user!;
    final app = _app!;
    final expectedContext = context!;
    final generation = epoch.advance();
    NotificationService? service;
    String? challenge;
    try {
      if (currentUid() != user.uid) return;
      if (!epoch.current(generation)) return;
      service = _service ?? await createService(user.tenantId, app, user.uid);
      if (!epoch.current(generation)) return;
      _service = service;
      final token = await obtainToken();
      if (!epoch.current(generation)) return;
      if (token == null) {
        final previous = _registration;
        _registration = null;
        _token = null;
        if (previous != null) await service.revoke(previous);
        return;
      }
      final agreement = await tabsAgree(expectedContext);
      if (!epoch.current(generation)) return;
      if (!agreement) {
        final previous = _registration;
        _registration = null;
        _token = null;
        if (_service != null && previous != null) {
          await _service!.revoke(previous);
        }
        return;
      }
      if (token == _token &&
          _registration != null &&
          (_registration!['expiresAt'] as num) >
              DateTime.now().millisecondsSinceEpoch +
                  const Duration(days: 1).inMilliseconds) {
        return;
      }
      if (_registration != null && !await service.validate(_registration!)) {
        if (!epoch.current(generation)) return;
        _registration = null;
        _token = null;
      }
      if (!epoch.current(generation)) return;
      challenge = base64UrlEncode(
        List<int>.generate(24, (_) => Random.secure().nextInt(256)),
      );
      _challenge = challenge;
      final proof = Completer<String>();
      _proof = proof;
      await service.begin(challenge, token, _registration);
      final received = await proof.future.timeout(const Duration(seconds: 60));
      if (!epoch.current(generation) ||
          received.isEmpty ||
          !await tabsAgree(expectedContext)) {
        return;
      }
      if (!epoch.current(generation)) return;
      final registration = await service.confirm(challenge, received);
      if (!epoch.current(generation)) {
        await service.cancel(challenge);
        return;
      }
      _registration = registration;
      _token = token;
      _challenge = null;
      _proof = null;
      challenge = null;
    } catch (_) {
      debugPrint('[notifications] registration-unavailable');
    } finally {
      if (challenge != null && service != null) {
        try {
          await service.cancel(challenge).timeout(const Duration(seconds: 2));
        } catch (_) {}
      }
      if (_challenge == challenge) {
        _challenge = null;
        _proof = null;
      }
      _busy = false;
      if (!epoch.current(generation) && _user != null) unawaited(_refresh());
    }
  }

  Future<bool> validateDisplay(Map<String, dynamic> data) async {
    final user = _user;
    final registration = _registration;
    final service = _service;
    if (user == null ||
        registration == null ||
        service == null ||
        !matchesNotificationContext(
          data,
          user,
          _app!,
          authenticatedUid: currentUid(),
        ) ||
        data['registrationId'] != registration['registrationId'] ||
        data['generation'] != registration['generation']) {
      return false;
    }
    final expected = context;
    try {
      final active = await service
          .validate(registration)
          .timeout(const Duration(seconds: 2));
      return active &&
          context == expected &&
          identical(_registration, registration) &&
          currentUid() == user.uid;
    } catch (_) {
      return false;
    }
  }
}
