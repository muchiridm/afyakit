// lib/features/messaging/notifications/notification_bootstrap.dart

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/features/messaging/notifications/chat_notification_service.dart';
import 'package:afyakit/features/messaging/notifications/foreground_notification/foreground_notification.dart';

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
  final ChatNotificationService _service = ChatNotificationService();

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

    final bool userChanged =
        oldWidget.user.uid != widget.user.uid ||
        oldWidget.user.tenantId != widget.user.tenantId ||
        oldWidget.user.isStaffResolved != widget.user.isStaffResolved ||
        oldWidget.user.contactId != widget.user.contactId ||
        oldWidget.user.accountNumber != widget.user.accountNumber;

    if (userChanged) {
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

  void _scheduleRegistration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(_initialise());
    });
  }

  Future<void> _initialise() async {
    if (_initialising) return;

    final String registrationKey =
        '${widget.user.tenantId}:${widget.user.uid}:'
        '${widget.user.isStaffResolved}:'
        '${widget.user.contactId ?? ''}:'
        '${widget.user.accountNumber ?? ''}';

    if (_registrationKey == registrationKey && _registeredToken != null) {
      return;
    }

    _initialising = true;

    try {
      final NotificationSettings settings = await _service.requestPermission();

      final AuthorizationStatus status = settings.authorizationStatus;

      final bool allowed =
          status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;

      if (!allowed) {
        debugPrint('🔕 Notifications not authorised: ${status.name}');

        return;
      }

      final String? token = await _service.getToken();

      if (token == null) {
        debugPrint('🔕 Firebase Messaging returned no token.');

        return;
      }

      await _service.registerDevice(user: widget.user, token: token);

      _registeredToken = token;
      _registrationKey = registrationKey;

      await _tokenSubscription?.cancel();

      _tokenSubscription = _service.onTokenRefresh.listen(
        (String refreshedToken) {
          unawaited(_registerRefreshedToken(refreshedToken));
        },
        onError: (Object error, StackTrace stack) {
          debugPrint('💥 FCM token refresh error: $error');
        },
      );

      debugPrint(
        '🔔 Notification device registered '
        'tenant=${widget.user.tenantId} '
        'uid=${widget.user.uid}',
      );
    } catch (error, stack) {
      debugPrint('💥 Notification registration failed: $error');

      debugPrintStack(stackTrace: stack);
    } finally {
      _initialising = false;
    }
  }

  Future<void> _registerRefreshedToken(String token) async {
    final String cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      return;
    }

    try {
      await _service.registerDevice(user: widget.user, token: cleanToken);

      _registeredToken = cleanToken;

      debugPrint('🔔 Refreshed notification token registered.');
    } catch (error, stack) {
      debugPrint('💥 Failed to register refreshed FCM token: $error');

      debugPrintStack(stackTrace: stack);
    }
  }

  void _listenForNotificationEvents() {
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (Object error, StackTrace stack) {
        debugPrint('💥 Foreground FCM listener error: $error');

        debugPrintStack(stackTrace: stack);
      },
    );

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
      onError: (Object error, StackTrace stack) {
        debugPrint('💥 Notification-open listener error: $error');

        debugPrintStack(stackTrace: stack);
      },
    );

    unawaited(_handleInitialMessage());
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final String type = (message.data['type'] ?? '').toString().trim();

    final String conversationId = (message.data['conversationId'] ?? '')
        .toString()
        .trim();

    debugPrint(
      '🔔 Foreground notification '
      'type=$type '
      'conversationId=$conversationId',
    );

    if (type != 'chat_message' || conversationId.isEmpty) {
      return;
    }

    unawaited(showForegroundNotification(message));
  }

  Future<void> _handleInitialMessage() async {
    final RemoteMessage? message = await FirebaseMessaging.instance
        .getInitialMessage();

    if (message == null || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _handleNotificationTap(message);
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final String type = (message.data['type'] ?? '').toString().trim();

    final String conversationId = (message.data['conversationId'] ?? '')
        .toString()
        .trim();

    if (type != 'chat_message' || conversationId.isEmpty) {
      return;
    }

    debugPrint('💬 Open chat notification: $conversationId');

    // Navigation remains intentionally separate from notification
    // delivery/presentation. Once the member/staff route contract is
    // confirmed, this can navigate directly to the conversation.
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
