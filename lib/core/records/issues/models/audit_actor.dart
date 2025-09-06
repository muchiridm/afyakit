// lib/core/records/issues/models/audit_actor.dart
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';

class AuditActor {
  final String uid;
  final String name; // snapshot of user label at action time
  final String role; // snapshot of role at action time
  const AuditActor({required this.uid, required this.name, required this.role});

  factory AuditActor.fromUser(AuthUser u) => AuditActor(
    uid: u.uid,
    name: resolveUserDisplay(
      displayName: u.displayName,
      email: u.email,
      phone: u.phoneNumber,
      uid: u.uid,
    ),
    role: u.role.name,
  );
}
