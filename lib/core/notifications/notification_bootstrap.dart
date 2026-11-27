// lib/core/notifications/notification_bootstrap.dart

import 'dart:async';
import 'notification_context.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/notifications/foreground_notification/foreground_notification.dart';
import 'package:afyakit/core/notifications/notification_service.dart';

class NotificationBootstrap extends StatefulWidget {
  const NotificationBootstrap({
    super.key,
    required this.user,
    required this.appId,
    required this.child,
  });

  final AuthUser user;
  final String appId;
  final Widget child;

  @override
  State<NotificationBootstrap> createState() => _NotificationBootstrapState();
}

class _NotificationBootstrapState extends State<NotificationBootstrap> {
  final NotificationService _service = NotificationService();

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  String? _registeredToken;
  String? _registrationKey;
  AuthUser? _registeredUser;
  String? _registeredAppId;

  bool _initialising = false;
  bool _registrationPending = false;

  String get _appId => widget.appId.trim().toLowerCase();

  @override
  void initState() {
    super.initState();

    _listenForNotificationEvents();
    _scheduleRegistration();
  }

  @override
  void didUpdateWidget(covariant NotificationBootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_registrationKeyFor(oldWidget.user, oldWidget.appId) !=
        _registrationKeyFor(widget.user, widget.appId)) {
      _scheduleRegistration();
    }
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();

    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Registration
  // ─────────────────────────────────────────────

  void _scheduleRegistration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(_initialise());
    });
  }

  Future<void> _initialise() async {
    if (_initialising) {
      _registrationPending = true;
      return;
    }

    final registrationKey = _registrationKeyFor(widget.user, widget.appId);

    if (_registrationKey == registrationKey && _registeredToken != null) {
      return;
    }

    if (_appId.isEmpty) {
      debugPrint('[notifications] operation');
      return;
    }

    _initialising = true;

    try {
      final settings = await _service.requestPermission();

      final status = settings.authorizationStatus;

      final allowed =
          status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;

      if (!allowed) {
        debugPrint('[notifications] operation');
        return;
      }

      final token = await _service.getToken();

      if (token == null) {
        debugPrint('[notifications] operation');
        return;
      }

      if (!mounted) return;

      // Do not register stale session/app context if
      // the selected application changed during
      // the asynchronous permission/token requests.
      if (registrationKey != _registrationKeyFor(widget.user, widget.appId)) {
        _registrationPending = true;
        return;
      }

      await _registerToken(token, registrationKey: registrationKey);

      if (!mounted) return;

      await _tokenSubscription?.cancel();

      _tokenSubscription = _service.onTokenRefresh.listen(
        (token) {
          unawaited(_registerRefreshedToken(token));
        },
        onError: (Object error, StackTrace stack) {
          debugPrint('[notifications] operation');
        },
      );

      debugPrint('[notifications] operation');
    } catch (error) {
      debugPrint('[notifications] operation');
    } finally {
      _initialising = false;

      if (_registrationPending && mounted) {
        _registrationPending = false;
        _scheduleRegistration();
      }
    }
  }

  Future<void> _registerToken(String token, {String? registrationKey}) async {
    final cleanToken = token.trim();

    if (cleanToken.isEmpty || _appId.isEmpty) {
      return;
    }

    final user = widget.user;
    final appId = _appId;
    final currentKey = _registrationKeyFor(user, appId);
    if (registrationKey != null && registrationKey != currentKey) return;

    await _service.replaceDeviceToken(
      user: user,
      appId: appId,
      token: cleanToken,
      previousUser: _registeredUser,
      previousAppId: _registeredAppId,
      previousToken: _registeredToken,
    );

    if (!mounted) return;

    // The selected app or account might have changed during the write.
    // A fresh bootstrap run will register the new session's identity.
    if (currentKey != _registrationKeyFor(widget.user, widget.appId)) {
      _registrationPending = true;
      return;
    }

    _registeredToken = cleanToken;
    _registeredUser = user;
    _registeredAppId = appId;
    _registrationKey = currentKey;
  }

  Future<void> _registerRefreshedToken(String token) async {
    try {
      final registrationKey = _registrationKeyFor(widget.user, widget.appId);

      await _registerToken(token, registrationKey: registrationKey);

      debugPrint('[notifications] operation');
    } catch (error) {
      debugPrint('[notifications] operation');
    }
  }

  // ─────────────────────────────────────────────
  // Notification listeners
  // ─────────────────────────────────────────────

  void _listenForNotificationEvents() {
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (Object error, StackTrace stack) {
        debugPrint('[notifications] operation');
      },
    );

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
      onError: (Object error, StackTrace stack) {
        debugPrint('[notifications] operation');
      },
    );

    unawaited(_handleInitialMessage());
  }

  bool _matchesActiveApp(RemoteMessage message) => matchesNotificationContext(
    message.data,
    widget.user,
    _appId,
    authenticatedUid: FirebaseAuth.instance.currentUser?.uid,
  );

  void _handleForegroundMessage(RemoteMessage message) {
    if (!_matchesActiveApp(message)) {
      debugPrint('[notifications] operation');
      return;
    }

    final type = _value(message.data['type']);

    debugPrint('[notifications] operation');

    switch (type) {
      case 'chat_message':
        unawaited(showForegroundNotification(message));
        return;

      case 'activity':
        unawaited(showForegroundNotification(message));
        return;

      default:
        debugPrint('[notifications] operation');
        return;
    }
  }

  Future<void> _handleInitialMessage() async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();

      if (message == null || !mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _handleNotificationTap(message);
      });
    } catch (error) {
      debugPrint('[notifications] operation');
    }
  }

  // ─────────────────────────────────────────────
  // Notification taps
  // ─────────────────────────────────────────────

  void _handleNotificationTap(RemoteMessage message) {
    if (!_matchesActiveApp(message)) {
      debugPrint('[notifications] operation');
      return;
    }

    final type = _value(message.data['type']);

    switch (type) {
      case 'chat_message':
        _handleChatTap(message);
        return;

      case 'activity':
        _handleActivityTap(message);
        return;

      default:
        debugPrint('[notifications] operation');
        return;
    }
  }

  // Pushes carry no resource details. Authenticated in-app lists remain authoritative.
  void _handleChatTap(RemoteMessage message) {}
  void _handleActivityTap(RemoteMessage message) {}

  String _registrationKeyFor(AuthUser user, String appId) {
    return [
      user.tenantId.trim().toLowerCase(),
      appId.trim().toLowerCase(),
      user.uid,
      user.isStaffResolved,
      user.accountNumber ?? '',
    ].join(':');
  }

  String _value(Object? value) {
    return value?.toString().trim() ?? '';
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
