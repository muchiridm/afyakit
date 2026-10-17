import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/auth/auth_session/controllers/login_controller.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

enum OnboardingNeed { phone, email, name, linkContact, none }

class OnboardingGate {
  static OnboardingNeed need(AuthUser user) {
    if (user.recoveryRequired) return OnboardingNeed.linkContact;
    if (!user.isPhoneSatisfiedResolved) return OnboardingNeed.phone;
    final onboarding = user.onboarding;
    if (onboarding == null) throw const FormatException('Missing server onboarding state');
    switch (onboarding.next) {
      case 'verify_email': return OnboardingNeed.email;
      case 'complete_contact': return OnboardingNeed.name;
      case 'link_contact': return OnboardingNeed.linkContact;
      case 'done': return OnboardingNeed.none;
      default: throw FormatException('Unsupported onboarding state: ${onboarding.next}');
    }
  }

  static void forceStep(WidgetRef ref, LoginStep step, {String? hint}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(loginControllerProvider.notifier);
      final state = ref.read(loginControllerProvider);
      if (state.busy) return;
      final inPhoneFlow = state.step == LoginStep.phone || state.step == LoginStep.otp;
      final inEmailFlow = state.step == LoginStep.emailEntry || state.step == LoginStep.emailOtp;
      if (step == LoginStep.phone && inPhoneFlow) return;
      if (step == LoginStep.emailEntry && inEmailFlow) return;
      if (step == LoginStep.nameEntry && state.step == LoginStep.nameEntry) return;
      ctrl.forceStep(step, hint: hint);
    });
  }
}
