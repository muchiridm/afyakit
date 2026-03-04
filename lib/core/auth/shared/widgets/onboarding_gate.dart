// lib/core/auth/shared/widgets/onboarding_gate.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_session/controllers/login_controller.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

enum OnboardingNeed { phone, email, name, none }

class OnboardingGate {
  static OnboardingNeed need(AuthUser user) {
    if (user.isPhoneSatisfiedResolved != true) return OnboardingNeed.phone;

    final hasEmail = user.hasEmail; // uses your AuthUser getter
    final verified = user.emailVerified == true;
    if (!(hasEmail && verified)) return OnboardingNeed.email;

    // name rules (match your current gate)
    final dn = (user.displayName ?? '').trim();
    if (dn.isEmpty) return OnboardingNeed.name;

    if (user.isCompany == true) {
      final cn = (user.companyName ?? '').trim();
      if (cn.isEmpty) return OnboardingNeed.name;
    } else {
      final fn = (user.firstName ?? '').trim();
      final ln = (user.lastName ?? '').trim();
      if (fn.isEmpty || ln.isEmpty) return OnboardingNeed.name;
    }

    return OnboardingNeed.none;
  }

  static void forceStep(WidgetRef ref, LoginStep step, {String? hint}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(loginControllerProvider.notifier);
      final st = ref.read(loginControllerProvider);

      if (st.busy) return;

      final inPhoneFlow =
          st.step == LoginStep.phone || st.step == LoginStep.otp;
      final inEmailFlow =
          st.step == LoginStep.emailEntry || st.step == LoginStep.emailOtp;
      final inNameFlow = st.step == LoginStep.nameEntry;

      if (step == LoginStep.phone && inPhoneFlow) return;
      if (step == LoginStep.emailEntry && inEmailFlow) return;
      if (step == LoginStep.nameEntry && inNameFlow) return;

      ctrl.forceStep(step, hint: hint);
    });
  }
}
