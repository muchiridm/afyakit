// lib/core/notifications/notification_bootstrap.dart

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/notifications/foreground_notification/foreground_notification.dart';
import 'package:afyakit/core/notifications/notification_service.dart';

class NotificationBootstrap extends StatefulWidget {
  const NotificationBootstrap({
    super.key,
    required this.user,
    required this.child,
  });

  final AuthUser user;
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

  bool _initialising = false;

  @override
  void initState() {
    super.initState();

    _listenForNotificationEvents();
    _scheduleRegistration();
  }

  @override
  void didUpdateWidget(covariant NotificationBootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_userRegistrationChanged(oldWidget.user, widget.user)) {
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
      if (!mounted) {
        return;
      }

      unawaited(_initialise());
    });
  }

  Future<void> _initialise() async {
    if (_initialising) {
      return;
    }

    final registrationKey = _registrationKeyFor(widget.user);

    if (_registrationKey == registrationKey && _registeredToken != null) {
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
        debugPrint(
          '🔕 Notifications not authorised: '
          '${status.name}',
        );

        return;
      }

      final token = await _service.getToken();

      if (token == null) {
        debugPrint('🔕 Firebase Messaging returned no token.');

        return;
      }

      await _registerToken(token, registrationKey: registrationKey);

      await _tokenSubscription?.cancel();

      _tokenSubscription = _service.onTokenRefresh.listen(
        (token) {
          unawaited(_registerRefreshedToken(token));
        },
        onError: (Object error, StackTrace stack) {
          debugPrint('💥 FCM token refresh error: $error');

          debugPrintStack(stackTrace: stack);
        },
      );

      debugPrint(
        '🔔 Notification device registered '
        'tenant=${widget.user.tenantId} '
        'uid=${widget.user.uid}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '💥 Notification registration failed: '
        '$error',
      );

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _initialising = false;
    }
  }

  Future<void> _registerToken(String token, {String? registrationKey}) async {
    final cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      return;
    }

    await _service.registerDevice(user: widget.user, token: cleanToken);

    _registeredToken = cleanToken;

    if (registrationKey != null) {
      _registrationKey = registrationKey;
    }
  }

  Future<void> _registerRefreshedToken(String token) async {
    try {
      await _registerToken(token);

      debugPrint('🔔 Refreshed notification token registered.');
    } catch (error, stackTrace) {
      debugPrint(
        '💥 Failed to register refreshed FCM token: '
        '$error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ─────────────────────────────────────────────
  // Notification listeners
  // ─────────────────────────────────────────────

  void _listenForNotificationEvents() {
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (Object error, StackTrace stack) {
        debugPrint(
          '💥 Foreground FCM listener error: '
          '$error',
        );

        debugPrintStack(stackTrace: stack);
      },
    );

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
      onError: (Object error, StackTrace stack) {
        debugPrint(
          '💥 Notification-open listener error: '
          '$error',
        );

        debugPrintStack(stackTrace: stack);
      },
    );

    unawaited(_handleInitialMessage());
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final type = _value(message.data['type']);

    debugPrint(
      '🔔 Foreground notification '
      'type=$type',
    );

    switch (type) {
      case 'chat_message':
        if (_conversationId(message).isEmpty) {
          return;
        }

        unawaited(showForegroundNotification(message));

        return;

      case 'activity':
        if (!_hasActivityEntity(message)) {
          return;
        }

        unawaited(showForegroundNotification(message));

        return;

      default:
        debugPrint(
          'ℹ️ Unsupported foreground '
          'notification type=$type',
        );
        return;
    }
  }

  Future<void> _handleInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();

    if (message == null || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _handleNotificationTap(message);
    });
  }

  // ─────────────────────────────────────────────
  // Notification taps
  // ─────────────────────────────────────────────

  void _handleNotificationTap(RemoteMessage message) {
    final type = _value(message.data['type']);

    switch (type) {
      case 'chat_message':
        _handleChatTap(message);
        return;

      case 'activity':
        _handleActivityTap(message);
        return;

      default:
        debugPrint(
          'ℹ️ Unsupported notification tap '
          'type=$type',
        );
        return;
    }
  }

  void _handleChatTap(RemoteMessage message) {
    final conversationId = _conversationId(message);

    if (conversationId.isEmpty) {
      return;
    }

    debugPrint(
      '💬 Open chat notification: '
      '$conversationId',
    );

    // TODO: navigate to conversation.
  }

  void _handleActivityTap(RemoteMessage message) {
    final entityType = _value(message.data['entityType']);

    final entityId = _value(message.data['entityId']);

    if (entityType.isEmpty || entityId.isEmpty) {
      return;
    }

    debugPrint(
      '🔔 Open activity notification '
      'entityType=$entityType '
      'entityId=$entityId',
    );

    // TODO: route using the same entity contract
    // used by Latest Activity.
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  bool _userRegistrationChanged(AuthUser previous, AuthUser current) {
    return previous.uid != current.uid ||
        previous.tenantId != current.tenantId ||
        previous.isStaffResolved != current.isStaffResolved ||
        previous.contactId != current.contactId ||
        previous.accountNumber != current.accountNumber;
  }

  String _registrationKeyFor(AuthUser user) {
    return [
      user.tenantId,
      user.uid,
      user.isStaffResolved,
      user.contactId ?? '',
      user.accountNumber ?? '',
    ].join(':');
  }

  String _conversationId(RemoteMessage message) {
    return _value(message.data['conversationId']);
  }

  bool _hasActivityEntity(RemoteMessage message) {
    return _value(message.data['entityType']).isNotEmpty &&
        _value(message.data['entityId']).isNotEmpty;
  }

  String _value(Object? value) {
    return value?.toString().trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
