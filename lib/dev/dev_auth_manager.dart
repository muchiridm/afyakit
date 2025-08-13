import 'package:afyakit/users/services/firebase_auth_service.dart';
import 'package:afyakit/users/utils/claim_validator.dart';
import 'package:afyakit/shared/providers/api_client_provider.dart';
import 'package:afyakit/shared/providers/tenant_provider.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dev_auth_result.dart';

class DevAuthManager {
  static const _devEmails = {
    'muchiridm@gmail.com',
    'dev@afyakit.app',
    'testdev@afyakit.app',
  };

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
    final currentUser = ref.read(firebaseAuthServiceProvider).currentUser;
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
    ref.read(tenantIdProvider); // ⏫ Prime it anyway

    final firebase = ref.read(firebaseAuthServiceProvider);
    final email = EmailHelper.normalize(
      overrideEmail ??
          Uri.base.queryParameters['email'] ??
          firebase.currentUser?.email ??
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
      final cred = await firebase.signInWithEmailAndPassword(
        email: email,
        password: _devPassword,
      );

      debugPrint('✅ Firebase signed in as ${cred.user?.email}');

      // 🔁 Backend claim sync
      try {
        final tokenProviderInstance = ref.read(tokenProvider);
        await tokenProviderInstance.getToken();
        final client = await ref.read(apiClientProvider.future);

        final response = await client.dio.post(
          '/users/check-user-status',
          data: {'email': email},
        );

        debugPrint('🔁 check-user-status → ${response.data}');
      } catch (syncErr) {
        debugPrint('⚠️ Claim sync failed: $syncErr');
      }

      // 🔐 Retry fetching claims (up to 3 times)
      bool claimsReady = false;
      Map<String, dynamic> claims = {};

      for (var attempt = 1; attempt <= 3; attempt++) {
        await cred.user?.getIdToken(true); // 🔄 Force refresh
        final result = await cred.user?.getIdTokenResult();
        claims = result?.claims ?? {};

        debugPrint('🔐 Attempt $attempt → Claims: $claims');

        if (ClaimValidator.isValid(claims, verbose: true)) {
          claimsReady = true;
          break;
        }

        await Future.delayed(const Duration(seconds: 1));
      }

      if (!claimsReady) {
        debugPrint('❌ Claims still missing after retries.');
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
