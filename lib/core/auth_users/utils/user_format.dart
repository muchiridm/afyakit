// lib/core/auth_users/utils/user_format.dart

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';

/// Initials from a display name. e.g. "John Doe" -> "JD", "Madonna" -> "M"
String initialsFromName(String name, {int max = 2}) {
  final trimmed = (name).trim();
  if (trimmed.isEmpty) return '?';

  final parts = trimmed
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

  final chars = <String>[parts.first[0], parts.last[0]];
  final out = chars.join().toUpperCase();
  return out.length > max ? out.substring(0, max) : out;
}

/// Human label for a role enum or string.
/// Accepts: UserRole enum, 'UserRole.admin', 'admin', 'ADMIN', 'viewOnly', etc.
String roleLabel(dynamic role) {
  if (role == null) return '—';

  // Enum? (Dart enums have .name)
  final raw = role is Enum ? role.name : role.toString();
  if (raw.trim().isEmpty) return '—';

  final last = raw.contains('.')
      ? raw.split('.').last
      : raw; // "UserRole.admin" -> "admin"
  return last.replaceAll(RegExp(r'[_\-]+'), ' ').toPascalCase();
}

/// Best user-facing label for an AuthUser (displayName → email → phone → uid).
String displayLabelFromUser(AuthUser? u) {
  if (u == null) return '';
  return resolveUserDisplay(
    displayName: u.displayName,
    email: u.email,
    phone: u.phoneNumber,
    uid: u.uid,
  );
}

/// Fallback name if you need a non-empty identifier (no fancy resolving).
String fallbackNameFor(AuthUser u) {
  if (u.displayName.trim().isNotEmpty) return u.displayName.trim();
  if (u.email.trim().isNotEmpty) return u.email.trim();
  if ((u.phoneNumber ?? '').trim().isNotEmpty) return u.phoneNumber!.trim();
  return u.uid;
}
