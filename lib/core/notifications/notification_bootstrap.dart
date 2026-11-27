import 'package:flutter/widgets.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'notification_lifecycle.dart';

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
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() =>
      NotificationLifecycle.instance.attach(this, widget.user, widget.appId);
  @override
  void didUpdateWidget(covariant NotificationBootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attach();
  }

  @override
  void dispose() {
    NotificationLifecycle.instance.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
