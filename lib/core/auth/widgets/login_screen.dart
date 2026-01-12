// lib/core/auth/widgets/login_screen.dart

import 'package:afyakit/core/auth/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/widgets/otp_login_screen.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantName = ref.watch(tenantDisplayNameProvider);

    return OtpLoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName));
  }
}
