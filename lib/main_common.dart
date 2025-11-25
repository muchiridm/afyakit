// lib/main_common.dart

import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

import 'package:afyakit/app/afyakit_app.dart';
import 'package:afyakit/hq/tenants/services/tenant_resolver.dart';

final authEmulatorEnabledProvider = Provider<bool>((_) => false);

final class BootLog {
  static void d(String msg) => debugPrint('🚀 $msg');
  static void e(String msg) => debugPrint('💥 $msg');
}

Future<void> bootstrapAndRun({required String defaultTenantSlug}) async {
  WidgetsFlutterBinding.ensureInitialized();

  _installGlobalErrorHandlers();

  BootLog.d('Initializing Firebase…');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final usingAuthEmulator = await _configureAuthForDev();
  _logFirebaseAppInfo(usingAuthEmulator);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  final invite = _extractInviteFromUri(Uri.base);

  final slug = await resolveTenantSlugAsync(defaultSlug: defaultTenantSlug);
  BootLog.d('Using v2 tenant: $slug');

  runApp(
    ProviderScope(
      overrides: [
        tenantSlugProvider.overrideWithValue(slug),
        authEmulatorEnabledProvider.overrideWithValue(usingAuthEmulator),
      ],
      child: AfyaKitApp(
        isInviteFlow: invite != null,
        inviteParams: invite != null
            ? <String, String>{'tenant': slug, 'uid': invite.uid}
            : null,
      ),
    ),
  );
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    BootLog.e('FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrintStack(stackTrace: details.stack);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    BootLog.e('ZoneError: $error');
    debugPrintStack(stackTrace: stack);
    return true; // prevent silent crash
  };
}

/// Shape for invite info
final class _InviteInfo {
  final String uid;
  const _InviteInfo(this.uid);
}

/// Parse /invite/accept?uid=... from current URL on web
_InviteInfo? _extractInviteFromUri(Uri uri) {
  BootLog.d('Uri.base = $uri  (pathSegments=${uri.pathSegments})');

  final segs = uri.pathSegments;
  final uid = uri.queryParameters['uid'];
  final isInviteFlow =
      segs.length >= 2 &&
      segs[0] == 'invite' &&
      segs[1] == 'accept' &&
      uid != null;

  BootLog.d('isInviteFlow=$isInviteFlow uid=$uid');

  if (!isInviteFlow) return null;
  return _InviteInfo(uid);
}

/// Print current Firebase wiring so we can see what project/build we’re on.
void _logFirebaseAppInfo(bool emulatorEnabled) {
  final o = Firebase.app().options;

  String mask(String? key) {
    if (key == null || key.isEmpty) return '-';
    return key.length > 8 ? '${key.substring(0, 6)}…' : key;
  }

  final origin = kIsWeb ? Uri.base.origin : 'app';
  final authDomain = kIsWeb ? (o.authDomain ?? '-') : '-';

  BootLog.d(
    '[AuthCFG] projectId=${o.projectId} appId=${o.appId} apiKey=${mask(o.apiKey)} '
    'authDomain=$authDomain origin=$origin authEmulator=${emulatorEnabled ? 'ON' : 'OFF'}',
  );
}

/// In debug: can opt in with
///   --dart-define=USE_AUTH_EMULATOR=true
Future<bool> _configureAuthForDev() async {
  if (!kDebugMode) return false;

  const useEmu = bool.fromEnvironment('USE_AUTH_EMULATOR', defaultValue: false);
  if (!useEmu) {
    BootLog.d('Firebase Auth emulator DISABLED (using real project).');
    try {
      await fb.FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: false,
      );
    } catch (_) {}
    return false;
  }

  const host = String.fromEnvironment(
    'AUTH_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  const port = int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);

  await fb.FirebaseAuth.instance.useAuthEmulator(host, port);
  BootLog.d('Firebase Auth emulator ENABLED at http://$host:$port');

  try {
    await fb.FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  } catch (_) {}

  return true;
}
