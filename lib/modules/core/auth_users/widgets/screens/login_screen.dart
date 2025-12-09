import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/shared/widgets/screens/otp_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantName = ref.watch(tenantDisplayNameProvider);

    return OtpLoginScreen(
      appTitle: tenantName,
      headerTitle: tenantName,
      headerSubtitle: 'Sign in with Email OTP',
      description: 'We will email you a one-time login code.',
    );
  }
}
