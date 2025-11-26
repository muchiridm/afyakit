// lib/core/auth_users/widgets/auth_gate.dart
import 'package:afyakit/core/auth_users/widgets/blocked.dart';
import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';
import 'package:afyakit/core/auth_users/controllers/auth_session/session_controller.dart';
import 'package:afyakit/core/auth_users/widgets/screens/user_profile_editor_screen.dart';
import 'package:afyakit/shared/widgets/home_screen/home_screen.dart';
import 'package:afyakit/shared/widgets/splash_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  final Map<String, String>? inviteParams;
  const AuthGate({super.key, this.inviteParams});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tenantId = ref.read(tenantSlugProvider);
      if (kDebugMode) {
        final u = fb.FirebaseAuth.instance.currentUser;
        debugPrint(
          '🔧 AuthGate.init → ensureReady() tenant=$tenantId fb.uid=${u?.uid} fb.email=${u?.email}',
        );
      }
      ref.read(sessionControllerProvider(tenantId).notifier).ensureReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(tenantSlugProvider);
    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    return sessionAsync.when(
      loading: () => const SplashScreen(),
      error: (e, _) {
        if (kDebugMode) debugPrint('💥 AuthGate: session error: $e');
        return const Blocked(
          msg: 'Error checking access. You can try signing out.',
          showSignOut: true,
        );
      },
      data: (user) {
        final fbUser = fb.FirebaseAuth.instance.currentUser;
        final hasFbUser = fbUser != null;

        if (user == null && hasFbUser) {
          if (kDebugMode) {
            debugPrint(
              '🌐 FB user present but no tenant membership → show PUBLIC home (guest on $tenantId)',
            );
          }
          return const HomeScreen();
        }

        if (user == null) {
          if (kDebugMode) debugPrint('🌐 Guest visit → Public Home');
          return const HomeScreen();
        }

        if (user.status.isInvited) {
          if (kDebugMode) debugPrint('📝 Invited → ProfileEditor');
          final params = widget.inviteParams ?? const <String, String>{};
          return UserProfileEditorScreen(
            tenantId: tenantId,
            inviteParams: params.isEmpty ? null : params,
          );
        }

        if (kDebugMode) debugPrint('✅ AuthGate OK → Home');
        return const HomeScreen();
      },
    );
  }
}
