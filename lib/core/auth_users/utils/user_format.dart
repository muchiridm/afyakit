// lib/core/auth_users/utils/user_format.dart
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';

// ── Formatting helpers you should keep ───────────────────────

String initialsFromName(String name, {int max = 2}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  final out = (parts.first[0] + parts.last[0]).toUpperCase();
  return out.length > max ? out.substring(0, max) : out;
}

String roleLabel(dynamic role) {
  if (role == null) return '—';
  final raw = role is Enum ? role.name : role.toString();
  final last = (raw.contains('.') ? raw.split('.').last : raw);
  return last.replaceAll(RegExp(r'[_\-]+'), ' ').toPascalCase();
}
