import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hq_auth_service.dart';

final hqAuthEngineProvider = Provider<HqAuthEngine>((ref) {
  final svc = ref.watch(hqAuthServiceProvider);
  return HqAuthEngine(svc: svc);
});

@immutable
class HqLoginOutcome {
  final bool signedIn;
  final bool allowed; // superadmin
  final String? email;
  const HqLoginOutcome({
    required this.signedIn,
    required this.allowed,
    this.email,
  });
}

class HqAuthEngine {
  final HqAuthService svc;
  HqAuthEngine({required this.svc});

  /// Sign in and immediately gate by the `superadmin` claim.
  /// FirebaseAuthException is allowed to bubble to caller for friendly mapping.
  Future<HqLoginOutcome> signInAndGate({
    required String email,
    required String password,
  }) async {
    final cred = await svc.signIn(email: email, password: password);
    final allowed = await svc.hasSuperadmin(force: true);
    if (!allowed) {
      // Keep HQ clean if a non-superadmin signs in
      await svc.signOut();
    }
    return HqLoginOutcome(
      signedIn: true,
      allowed: allowed,
      email: cred.user?.email,
    );
  }

  /// Re-check current user's gate (fresh claims).
  Future<bool> refreshAndGate() => svc.hasSuperadmin(force: true);
}
