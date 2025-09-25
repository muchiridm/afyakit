// lib/main_common.dart

import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

import 'package:afyakit/app/afyakit_app.dart';
import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/hq/tenants/services/tenant_resolver.dart';
import 'package:afyakit/hq/tenants/services/tenant_config_loader.dart';

/// Optional: expose whether the Auth emulator is enabled to the UI (for a banner, etc.)
final authEmulatorEnabledProvider = Provider<bool>((_) => false);

Future<void> bootstrapAndRun({required String defaultTenantSlug}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configure Auth for dev; returns whether the emulator is actually enabled.
  final usingAuthEmulator = await _configureAuthForDev();

  _logFirebaseAppInfo(usingAuthEmulator);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Invite-accept detection (unchanged)
  final uri = Uri.base;
  final segs = uri.pathSegments;
  final uid = uri.queryParameters['uid'];
  final isInviteFlow =
      segs.length >= 2 &&
      segs[0] == 'invite' &&
      segs[1] == 'accept' &&
      uid != null;

  // Resolve tenant & load config
  final slug = await resolveTenantSlugAsync(defaultSlug: defaultTenantSlug);
  debugPrint('🏢 Using tenant: $slug');

  final loader = TenantConfigLoader(FirebaseFirestore.instance);
  final cfg = await loader.load(slug);

  runApp(
    ProviderScope(
      overrides: [
        tenantIdProvider.overrideWithValue(slug),
        tenantConfigProvider.overrideWithValue(cfg),
        authEmulatorEnabledProvider.overrideWithValue(usingAuthEmulator),
      ],
      child: AfyaKitApp(
        isInviteFlow: isInviteFlow,
        inviteParams: isInviteFlow
            ? <String, String>{'tenant': slug, 'uid': uid}
            : null,
      ),
    ),
  );
}

/// Prints Firebase wiring + whether the Auth emulator is enabled.
void _logFirebaseAppInfo(bool emulatorEnabled) {
  final o = Firebase.app().options;

  String mask(String? key) {
    if (key == null || key.isEmpty) return '-';
    return key.length > 8 ? '${key.substring(0, 6)}…' : key;
  }

  // Only use Uri.base.origin on web; on mobile it's file:/// and .origin throws.
  final origin = kIsWeb ? Uri.base.origin : 'app';

  // authDomain is only meaningful on web
  final authDomain = (kIsWeb ? (o.authDomain ?? '-') : '-');

  debugPrint(
    '[AuthCFG] projectId=${o.projectId} appId=${o.appId} apiKey=${mask(o.apiKey)} '
    'authDomain=$authDomain origin=$origin authEmulator=${emulatorEnabled ? 'ON' : 'OFF'}',
  );
}

/// In debug builds, you can opt-in to the Auth emulator with:
///   --dart-define=USE_AUTH_EMULATOR=true
/// Default is OFF to keep client & backend in the same (production) auth realm.
Future<bool> _configureAuthForDev() async {
  if (!kDebugMode) return false;

  const useEmu = bool.fromEnvironment('USE_AUTH_EMULATOR', defaultValue: false);
  if (!useEmu) {
    debugPrint('✅ Firebase Auth emulator DISABLED (using real project).');
    // WA-OTP is server-side; no SMS app verification bypass needed.
    try {
      await fb.FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: false,
      );
    } catch (_) {
      /* no-op on web */
    }
    return false;
  }

  const host = String.fromEnvironment(
    'AUTH_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  const port = int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
  await fb.FirebaseAuth.instance.useAuthEmulator(host, port);
  debugPrint('👩‍🔬 Firebase Auth emulator ENABLED at http://$host:$port');

  // Optional: turn off app verification only when truly testing SMS (not needed for WA-OTP)
  try {
    await fb.FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  } catch (_) {
    /* no-op on web */
  }

  return true;
}
