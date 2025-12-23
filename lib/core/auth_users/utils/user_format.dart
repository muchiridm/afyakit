// lib/core/auth_users/utils/user_format.dart
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/extensions/staff_role_x.dart';

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

/// Primary label for displaying a user's "role" in the UI.
///
/// - If the user has one or more staffRoles → highest-precedence StaffRole.label.
/// - If no staffRoles → "Staff".
String staffRoleLabel(AuthUser user) {
  // if (user.isSuperAdmin) return 'Superadmin'; // optional special-case

  if (user.staffRoles.isEmpty) {
    return 'Staff';
  }

  final roles = [...user.staffRoles];
  roles.sort((a, b) => b.level.compareTo(a.level)); // highest level first

  return roles.first.label;
}
