// lib/core/auth/shared/widgets/onboarding_gate.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_session/controllers/login_controller.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

enum OnboardingNeed { phone, email, name, none }

class OnboardingGate {
  static OnboardingNeed need(AuthUser user) {
    // Phone verification is shared across all applications.
    if (!user.isPhoneSatisfiedResolved) {
      return OnboardingNeed.phone;
    }

    // Email verification belongs to the selected application.
    final appId = user.activeAppId?.trim().toLowerCase();

    if (appId == null || appId.isEmpty) {
      return OnboardingNeed.email;
    }

    final appEmail = user.emailsByApp[appId];

    if (appEmail == null || !appEmail.verified) {
      return OnboardingNeed.email;
    }

    // Name requirements remain shared within the tenant.
    final displayName = (user.displayName ?? '').trim();

    if (displayName.isEmpty) {
      return OnboardingNeed.name;
    }

    if (user.isCompany) {
      final companyName = (user.companyName ?? '').trim();

      if (companyName.isEmpty) {
        return OnboardingNeed.name;
      }
    } else {
      final firstName = (user.firstName ?? '').trim();
      final lastName = (user.lastName ?? '').trim();

      if (firstName.isEmpty || lastName.isEmpty) {
        return OnboardingNeed.name;
      }
    }

    return OnboardingNeed.none;
  }

  static void forceStep(WidgetRef ref, LoginStep step, {String? hint}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(loginControllerProvider.notifier);
      final state = ref.read(loginControllerProvider);

      if (state.busy) return;

      final inPhoneFlow =
          state.step == LoginStep.phone || state.step == LoginStep.otp;

      final inEmailFlow =
          state.step == LoginStep.emailEntry ||
          state.step == LoginStep.emailOtp;

      final inNameFlow = state.step == LoginStep.nameEntry;

      if (step == LoginStep.phone && inPhoneFlow) return;
      if (step == LoginStep.emailEntry && inEmailFlow) return;
      if (step == LoginStep.nameEntry && inNameFlow) return;

      ctrl.forceStep(step, hint: hint);
    });
  }
}
