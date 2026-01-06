// lib/hq/auth/hq_login_screen.dart

import 'package:afyakit/shared/widgets/screens/otp_login_screen.dart';
import 'package:flutter/material.dart';

/// HQ login uses the shared OTP flow (phone + email OTP).
/// Superadmin gating is enforced by HqGate via Firebase custom claims.
class HqLoginScreen extends StatelessWidget {
  const HqLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OtpLoginScreen(
      appTitle: 'AfyaKit HQ',
      headerTitle: 'AfyaKit HQ',
      headerSubtitle: 'Superadmin accounts only',
      description:
          'Enter the phone and email linked to your HQ account.\n'
          'We will email you a one-time login code.',
    );
  }
}
