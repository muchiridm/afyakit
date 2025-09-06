// lib/shared/utils/resolvers/resolve_user_display.dart

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';

/// Returns the best user-facing identifier:
/// displayName → email → phone → uid
String resolveUserDisplay({
  String? displayName,
  String? email,
  String? phone,
  required String uid,
}) {
  final name = (displayName ?? '').trim();
  if (name.isNotEmpty) return name;

  final mail = (email ?? '').trim();
  if (mail.isNotEmpty) return mail;

  final ph = (phone ?? '').trim();
  if (ph.isNotEmpty) return ph;

  return uid;
}

/// Nice, reusable sugar wherever you already have an AuthUser.
extension AuthUserDisplayX on AuthUser {
  String displayLabel() => resolveUserDisplay(
    displayName: displayName,
    email: email,
    phone: phoneNumber,
    uid: uid,
  );
}
