import 'dart:async'; // for unawaited()

import 'package:afyakit/core/auth_users/widgets/blocked.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';
import 'package:afyakit/core/auth_users/controllers/auth_session/session_controller.dart';

import 'package:afyakit/core/auth_users/screens/login_screen.dart';
import 'package:afyakit/core/auth_users/screens/user_profile_editor_screen.dart';
import 'package:afyakit/shared/screens/home_screen/home_screen.dart';
import 'package:afyakit/shared/screens/splash_screen.dart';

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
    // Warm the session (non-blocking)
    Future.microtask(() {
      final tenantId = ref.read(tenantIdProvider);
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
    final tenantId = ref.watch(tenantIdProvider);

    // ✅ Keep it simple: drive the app off the session controller alone.
    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    return sessionAsync.when(
      loading: () {
        if (kDebugMode) debugPrint('⌛ AuthGate: session loading…');
        return const SplashScreen();
      },
      error: (e, _) {
        if (kDebugMode) debugPrint('💥 AuthGate: session error: $e');
        return const Blocked(
          msg: 'Error checking access. You can try signing out.',
          showSignOut: true,
        );
      },
      data: (user) {
        // No app-user resolved yet
        if (user == null) {
          final hasFbUser = fb.FirebaseAuth.instance.currentUser != null;

          // If Firebase still has a user, we’re rehydrating → stay on Splash & nudge engine.
          if (hasFbUser) {
            if (kDebugMode) {
              debugPrint(
                '🧊 Firebase has user but session==null → keep Splash',
              );
            }
            Future.microtask(() {
              ref
                  .read(sessionControllerProvider(tenantId).notifier)
                  .ensureReady();
            });
            return const SplashScreen();
          }

          if (kDebugMode) debugPrint('👤 No session user → Login');
          return const LoginScreen();
        }

        // Invited → complete profile (one simple flow)
        if (user.status.isInvited) {
          if (kDebugMode) debugPrint('📝 Invited → ProfileEditor');
          return UserProfileEditorScreen(
            tenantId: tenantId,
            inviteParams: widget.inviteParams,
          );
        }

        // Active → go Home
        if (kDebugMode) debugPrint('✅ AuthGate OK → Home');
        return const HomeScreen();
      },
    );
  }
}
