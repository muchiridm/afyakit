// lib/core/records/issues/models/audit_actor.dart
import 'package:afyakit/modules/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/modules/core/auth_users/utils/user_format.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';

/// Lightweight snapshot of "who did what" at the time of an action.
///
/// - [uid]: stable Firebase UID
/// - [name]: human-friendly label at the time (displayName/phone/uid)
/// - [role]: snapshot label of their effective role ("Member", "Admin", etc.)
class AuditActor {
  final String uid;
  final String name; // snapshot of user label at action time
  final String role; // snapshot of role label at action time

  const AuditActor({required this.uid, required this.name, required this.role});

  factory AuditActor.fromUser(AuthUser u) {
    final display = resolveUserDisplay(
      displayName: u.displayName,
      email: '', // ⬅️ keep email out of the display chain
      phone: u.phoneNumber,
      uid: u.uid,
    );

    // "Member" if no staff roles, otherwise highest staff role label
    final roleLabel = staffRoleLabel(u);

    return AuditActor(uid: u.uid, name: display, role: roleLabel);
  }
}
