// lib/features/dev/dev_auth_manager.dart
import 'package:afyakit/core/auth_users/utils/claim_validator.dart';
import 'package:afyakit/api/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/core/auth_users/services/user_operations_service.dart';

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
    final currentUser = ref.read(firebaseOnlyUserOpsProvider).currentUser;
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
    final ops = ref.read(firebaseOnlyUserOpsProvider);

    final email = EmailHelper.normalize(
      overrideEmail ??
          Uri.base.queryParameters['email'] ??
          ops.currentUser?.email ??
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
      // 1) Firebase sign-in
      await ops.signInWithEmailAndPassword(
        email: email,
        password: _devPassword,
      );
      debugPrint('✅ Firebase signed in as ${ops.currentUser?.email}');

      // 2) Ensure API token & hit backend to sync claims/session
      try {
        final tokenProviderInstance = ref.read(tokenProvider);
        await tokenProviderInstance.getToken(); // ensures Firebase token exists

        final tenantId = ref.read(tenantIdProvider);
        final routes = ApiRoutes(tenantId);
        final client = await ref.read(apiClientProvider.future);

        final response = await client.dio.postUri(
          routes.checkUserStatus(), // canonical claims/session sync
          data: {'email': email},
        );
        debugPrint('🔁 check-user-status → ${response.data}');
      } catch (syncErr) {
        debugPrint('⚠️ Claim/session sync failed: $syncErr');
      }

      // 3) Retry a couple times for claims to appear
      bool claimsReady = false;
      Map<String, dynamic> claims = {};

      for (var attempt = 1; attempt <= 3; attempt++) {
        await ops.refreshToken(); // force refresh
        try {
          claims = await ops.getClaims();
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
        // Not fatal; UI hydrates from auth_users anyway.
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
