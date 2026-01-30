// lib/hq/auth/hq_login_screen.dart

import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:flutter/material.dart';

/// HQ login uses the shared OTP flow (phone + email OTP).
/// Superadmin gating is enforced by HqGate via Firebase custom claims.
class HqLoginScreen extends StatelessWidget {
  const HqLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen(copy: OtpLoginCopy.hq);
  }
}
