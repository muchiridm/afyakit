// lib/features/dev/dev_auth_manager.dart
import 'package:afyakit/core/auth_users/services/login_service.dart';
import 'package:afyakit/core/auth_users/services/auth_session_service.dart'; // ⬅️ NEW
import 'package:afyakit/core/auth_users/utils/claim_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';

import 'dev_auth_result.dart';

class DevAuthManager {
  static const _devEmails = {'muchiridm@gmail.com'};
  static const _devPassword = 'letmein';
  static String? _lastAttemptedEmail;

  static bool get isLocalhost => Uri.base.host == 'localhost';

  static bool isDevEmail(String? email) {
    final normalized = EmailHelper.normalize(email ?? '');
    return _devEmails.contains(normalized);
  }

  static bool isDevLoginIntent(WidgetRef ref) {
    final queryEmail = EmailHelper.normalize(
      Uri.base.queryParameters['email'] ?? '',
    );
    final currentUser = ref.read(loginServiceFirebaseOnlyProvider).currentUser;
    final currentEmail = EmailHelper.normalize(currentUser?.email ?? '');

    final match = isDevEmail(queryEmail) || isDevEmail(currentEmail);

    debugPrint(
      '🔍 Dev Login Intent → query="$queryEmail", current="$currentEmail", match=$match',
    );
    return match;
  }

  static Future<DevAuthResult> maybeSignInDevUser({
    required Ref ref,
    String? overrideEmail,
    bool forceRetry = false,
  }) async {
    final loginSvc = ref.read(loginServiceFirebaseOnlyProvider);

    final email = EmailHelper.normalize(
      overrideEmail ??
          Uri.base.queryParameters['email'] ??
          loginSvc.currentUser?.email ??
          (kDebugMode && isLocalhost ? 'muchiridm@gmail.com' : ''),
    );

    if (email.isEmpty) {
      debugPrint('⚠️ No email available for dev login.');
      return const DevAuthResult(
        success: false,
        claimsSynced: false,
        message: 'Dev login skipped: email missing.',
      );
    }

    if (_lastAttemptedEmail == email && !forceRetry) {
      debugPrint('⏭️ Dev login already attempted for $email.');
      return const DevAuthResult(success: true, claimsSynced: true);
    }

    if (!kDebugMode || !isLocalhost || !isDevEmail(email)) {
      debugPrint(
        '🚫 Dev login skipped (debug=$kDebugMode, localhost=$isLocalhost, email=$email)',
      );
      return const DevAuthResult(
        success: false,
        claimsSynced: false,
        message: 'Not in dev mode or email not whitelisted.',
      );
    }

    _lastAttemptedEmail = email;
    debugPrint('🧪 Attempting dev login with: $email');

    try {
      // 1) Firebase sign-in (client-only)
      await loginSvc.signInWithEmailAndPassword(
        email: email,
        password: _devPassword,
      );
      await loginSvc.waitForUser();
      debugPrint('✅ Firebase signed in as ${loginSvc.currentUser?.email}');

      // 2) Session ops (backend membership + claims path)
      final tenantId = ref.read(tenantIdProvider);
      final sessionOps = await ref.read(
        authSessionServiceProvider(tenantId).future,
      );

      // Probe membership (non-fatal if backend still warming)
      try {
        await sessionOps.checkUserStatus(email: email, useCache: false);
      } catch (probeErr) {
        debugPrint('ℹ️ Membership probe failed/late (continuing): $probeErr');
      }

      // Ask server to sync claims, then hydrate locally (best-effort)
      try {
        await sessionOps.syncClaimsAndRefresh();
      } catch (syncErr) {
        debugPrint('⚠️ Claim/session sync failed: $syncErr');
      }

      // 3) Retry for claims to show up (tight loop, small N)
      bool claimsReady = false;
      Map<String, dynamic> claims = {};

      for (var attempt = 1; attempt <= 3; attempt++) {
        await sessionOps.forceRefreshIdToken();
        try {
          claims = await sessionOps.getClaims(force: true);
        } catch (_) {
          claims = const {};
        }

        debugPrint('🔐 Attempt $attempt → Claims: $claims');

        if (ClaimValidator.isValid(claims, verbose: true)) {
          claimsReady = true;
          break;
        }
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!claimsReady) {
        debugPrint('❌ Claims still missing after retries (continuing).');
        return DevAuthResult(
          success: true,
          claimsSynced: false,
          message: 'Signed in, but claims not available after retries.',
        );
      }

      return const DevAuthResult(success: true, claimsSynced: true);
    } catch (e, st) {
      debugPrint('❌ Dev login failed: $e\n$st');
      return DevAuthResult(
        success: false,
        claimsSynced: false,
        message: 'Dev login failed: $e',
      );
    }
  }
}
