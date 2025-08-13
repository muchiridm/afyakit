import 'package:afyakit/users/models/auth_user_status_enum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/users/controllers/user_session_controller.dart';
import 'package:afyakit/users/screens/login_screen.dart';
import 'package:afyakit/users/screens/splash_screen.dart';
import 'package:afyakit/users/screens/user_profile_editor_screen.dart';

import 'package:afyakit/shared/screens/home_screen/home_screen.dart';
import 'package:afyakit/shared/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/providers/users/combined_user_provider.dart';

import 'package:afyakit/users/models/auth_user_status_x.dart';

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
      ref.read(userSessionControllerProvider(tenantId).notifier).ensureReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(tenantIdProvider);
    final authState = ref.watch(userSessionControllerProvider(tenantId));
    final combinedState = ref.watch(combinedUserProvider);

    final authUser = authState.value;
    final combinedUser = combinedState.value;
    final isLoading = authState.isLoading || combinedState.isLoading;

    if (isLoading) {
      debugPrint('⏳ AuthGate: Still loading auth or user profile...');
      return const SplashScreen();
    }

    if (authUser == null) {
      debugPrint('⛔️ AuthGate: No auth user found — redirecting to login');
      return const LoginScreen();
    }

    if (combinedState.hasError) {
      debugPrint('❌ AuthGate: CombinedUser load error: ${combinedState.error}');
      return const Center(child: Text('Error loading user profile.'));
    }

    if (combinedUser == null) {
      debugPrint('👻 AuthGate: CombinedUser is null — still initializing...');
      return const SplashScreen();
    }

    final statusEnum = AuthUserStatus.fromString(authUser.status);

    if (statusEnum.isInvited) {
      debugPrint(
        '📝 AuthGate: User is invited → redirecting to profile editor',
      );
      return UserProfileEditorScreen(
        tenantId: tenantId,
        inviteParams: widget.inviteParams,
      );
    }

    if (!statusEnum.isActive) {
      debugPrint('⛔️ AuthGate: User status is not active → ${authUser.status}');
      return const LoginScreen();
    }

    debugPrint('✅ AuthGate: All good → launching HomeScreen');
    return const HomeScreen();
  }
}
