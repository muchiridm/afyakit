// lib/main_common.dart

import 'dart:async';

import 'package:afyakit/app/app_mode.dart';
import 'package:afyakit/app/app_root.dart';
import 'package:afyakit/core/domains/services/domain_tenant_resolver.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'package:afyakit/shared/debug/riverpod_logger.dart';

final authEmulatorEnabledProvider = Provider<bool>((_) => false);

final class BootLog {
  static void d(String msg) => debugPrint('🚀 $msg');
  static void e(String msg) => debugPrint('💥 $msg');
}

Future<void> bootstrapAndRun({
  required String defaultTenantSlug,
  AppMode appMode = AppMode.tenant,
}) async {
  // ✅ EnsureInitialized + runApp MUST be in the same zone.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      _installGlobalErrorHandlers();

      BootLog.d('Initializing Firebase…');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final usingAuthEmulator = await _configureAuthForDev();
      _logFirebaseAppInfo(usingAuthEmulator);

      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );

      // Resolve tenant slug only for tenant mode.
      String? resolvedSlug;
      if (appMode == AppMode.tenant) {
        final slug = await resolveTenantSlugAsync(
          defaultSlug: defaultTenantSlug,
        );
        resolvedSlug = slug;
        BootLog.d('Using tenant: $slug');
      } else {
        BootLog.d('Running in HQ mode (no tenant slug resolution)');
      }

      runApp(
        ProviderScope(
          observers: const [RiverpodLogger()],
          overrides: [
            authEmulatorEnabledProvider.overrideWithValue(usingAuthEmulator),
            if (resolvedSlug != null)
              tenantSlugProvider.overrideWithValue(resolvedSlug),
          ],
          child: AppRoot(mode: appMode),
        ),
      );
    },
    (Object error, StackTrace stack) {
      BootLog.e('ZoneError(runZonedGuarded): $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    BootLog.e('FlutterError: ${details.exceptionAsString()}');
    final st = details.stack;
    if (st != null) debugPrintStack(stackTrace: st);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    BootLog.e('PlatformDispatcherError: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };
}

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
