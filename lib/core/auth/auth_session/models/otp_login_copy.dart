// lib/core/auth/models/otp_login_copy.dart

import 'package:flutter/foundation.dart';

@immutable
class OtpLoginCopy {
  final String appTitle;
  final String headerTitle;
  final String headerSubtitle;
  final String description;

  const OtpLoginCopy({
    required this.appTitle,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.description,
  });

  factory OtpLoginCopy.tenant({required String tenantName}) {
    final name = tenantName.trim().isEmpty ? 'AfyaKit' : tenantName.trim();

    return OtpLoginCopy(
      appTitle: name,
      headerTitle: name,
      headerSubtitle: 'Sign in with Email OTP',
      description: 'We will email you a one-time login code.',
    );
  }

  static const OtpLoginCopy hq = OtpLoginCopy(
    appTitle: 'AfyaKit HQ',
    headerTitle: 'AfyaKit HQ',
    headerSubtitle: 'Superadmin accounts only',
    description:
        'Enter the phone and email linked to your HQ account.\n'
        'We will email you a one-time login code.',
  );
}
