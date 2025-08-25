// lib/.../auth_gate.dart  (same file you showed)
import 'package:afyakit/features/auth_users/providers/current_auth_user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/shared/screens/splash_screen.dart';
import 'package:afyakit/features/auth_users/screens/user_profile_editor_screen.dart';
import 'package:afyakit/shared/screens/home_screen/home_screen.dart';

import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/features/auth_users/user_operations/controllers/session_controller.dart';
import 'package:afyakit/features/auth_users/user_manager/extensions/user_status_x.dart';

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
    Future.microtask(() {
      final tenantId = ref.read(tenantIdProvider);
      if (kDebugMode) {
        final u = fb.FirebaseAuth.instance.currentUser;
        debugPrint(
          '🔧 AuthGate.init → ensureReady() tenant=$tenantId '
          'fb.uid=${u?.uid} fb.email=${u?.email}',
        );
      }
      ref.read(sessionControllerProvider(tenantId).notifier).ensureReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(tenantIdProvider);
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    if (kDebugMode) {
      debugPrint(
        '🔑 AuthGate.build tenant=$tenantId '
        'fb.uid=${fbUser?.uid} fb.email=${fbUser?.email}',
      );
    }

    // Authoritative tenant membership (can be null == no access)
    final authUserAsync = ref.watch(currentAuthUserProvider);

    return authUserAsync.when(
      loading: () {
        if (kDebugMode) {
          debugPrint('⌛ AuthGate: waiting for currentAuthUser...');
        }
        return const SplashScreen();
      },
      error: (e, st) {
        if (kDebugMode) {
          debugPrint('💥 AuthGate: currentAuthUser ERROR: $e');
          debugPrint('$st');
        }
        return _Blocked(msg: 'Error checking access: $e');
      },
      data: (authUser) {
        if (authUser == null) {
          if (kDebugMode) {
            debugPrint(
              '🚫 AuthGate: currentAuthUser=null → no membership for tenant=$tenantId',
            );
          }
          return const _Blocked(
            msg: 'No access to this tenant. Ask an admin to invite you.',
          );
        }

        if (kDebugMode) {
          debugPrint(
            '✅ AuthGate: membership OK '
            'tenant=$tenantId uid=${authUser.uid} '
            'status=${authUser.status} role=${authUser.role} '
            'claimsKeys=${(authUser.claims!.keys.toList()..sort()).join(",")}',
          );
        }

        final statusEnum = UserStatus.fromString(authUser.status);
        if (statusEnum.isInvited) {
          if (kDebugMode) {
            debugPrint('📝 AuthGate: status=invited → profile editor');
          }
          return UserProfileEditorScreen(
            tenantId: tenantId,
            inviteParams: widget.inviteParams,
          );
        }

        if (!statusEnum.isActive) {
          if (kDebugMode) {
            debugPrint('⛔ AuthGate: status=${authUser.status} → blocked');
          }
          return const _Blocked(
            msg: 'Your access to this tenant is not active.',
          );
        }

        if (kDebugMode) debugPrint('🏠 AuthGate: launching HomeScreen');
        return const HomeScreen();
      },
    );
  }
}

class _Blocked extends StatelessWidget {
  const _Blocked({required this.msg});
  final String msg;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 48),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(msg, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}
