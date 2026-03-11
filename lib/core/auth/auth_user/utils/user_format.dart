// lib/core/auth_users/utils/user_format.dart
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart'; // StaffRole + primaryRole

String initialsFromName(String name, {int max = 2}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';

  final parts = trimmed
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();

  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  final out = (parts.first[0] + parts.last[0]).toUpperCase();
  return out.length > max ? out.substring(0, max) : out;
}

/// Generic enum/string → human label helper.
String roleLabel(dynamic role) {
  if (role == null) return '—';
  final raw = role is Enum ? role.name : role.toString();
  final last = (raw.contains('.') ? raw.split('.').last : raw);
  return last.replaceAll(RegExp(r'[_\\-]+'), ' ').toPascalCase();
}

/// Truth: user participates in staff ecosystem if:
/// - isSuperAdmin OR has one or more staffRoles.
/// (We do NOT trust `type` for labels during migrations/dirty payloads.)
bool hasStaffWorkspace(AuthUser user) =>
    user.isSuperAdmin || user.staffRoles.isNotEmpty;

/// Primary label for displaying a user's "role" in the UI.
///
/// Rules:
/// - If NOT staff ecosystem → "Member"
/// - If superadmin → "Owner" (or change to "Super Admin" if you prefer)
/// - Else → highest precedence StaffRole.label
/// - Else (shouldn't happen if staffRoles non-empty) → "Staff"
String staffRoleLabel(AuthUser user) {
  if (!hasStaffWorkspace(user)) return 'Member';

  if (user.isSuperAdmin) {
    // choose your preferred wording:
    return 'Owner'; // or 'Super Admin'
  }

  final primary = user.staffRoles.primaryRole;
  return primary?.label ?? 'Staff';
}
