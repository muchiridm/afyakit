// lib/main_common.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

import 'package:afyakit/app/app_mode.dart';
import 'package:afyakit/app/app_root.dart';
import 'package:afyakit/hq/domains/services/domain_tenant_resolver.dart';
import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/shared/debug/riverpod_logger.dart';

/// ─────────────────────────────────────────────
/// Providers
/// ─────────────────────────────────────────────

final authEmulatorEnabledProvider = Provider<bool>((_) => false);

/// ─────────────────────────────────────────────
/// Boot logger
/// ─────────────────────────────────────────────

final class BootLog {
  static void d(String msg) => debugPrint('🚀 $msg');
  static void e(String msg) => debugPrint('💥 $msg');
}

/// ─────────────────────────────────────────────
/// Bootstrap
/// ─────────────────────────────────────────────

Future<void> bootstrapAndRun({
  required String defaultTenantSlug,
  AppMode appMode = AppMode.tenant,
}) async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _installGlobalErrorHandlers();

      // ── Firebase init ────────────────────────
      BootLog.d('Initializing Firebase…');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final usingAuthEmulator = await _configureAuthForDev();
      _logFirebaseAppInfo(usingAuthEmulator);

      // ── Firestore (platform-aware) ───────────
      await _configureFirestoreForPlatform();

      // ── Tenant resolution ────────────────────
      String? resolvedSlug;
      if (appMode == AppMode.tenant) {
        resolvedSlug = await resolveTenantSlugAsync(
          defaultSlug: defaultTenantSlug,
        );
        BootLog.d('Using tenant: $resolvedSlug');
      } else {
        BootLog.d('Running in HQ mode (no tenant resolution)');
      }

      // ── Run app ──────────────────────────────
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
    (error, stack) {
      BootLog.e('ZoneError: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

/// ─────────────────────────────────────────────
/// Global error handlers
/// ─────────────────────────────────────────────

void _installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    BootLog.e('FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrintStack(stackTrace: details.stack!);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    BootLog.e('PlatformDispatcherError: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };
}

/// ─────────────────────────────────────────────
/// Firebase Auth (emulator-safe)
/// ─────────────────────────────────────────────

Future<bool> _configureAuthForDev() async {
  if (!kDebugMode) return false;

  const useEmulator = bool.fromEnvironment(
    'USE_AUTH_EMULATOR',
    defaultValue: false,
  );

  if (!useEmulator) {
    BootLog.d('Firebase Auth emulator DISABLED');
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

  try {
    await fb.FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  } catch (_) {}

  BootLog.d('Firebase Auth emulator ENABLED at http://$host:$port');
  return true;
}

/// ─────────────────────────────────────────────
/// Firestore (IMPORTANT PART)
/// ─────────────────────────────────────────────

Future<void> _configureFirestoreForPlatform() async {
  final fs = FirebaseFirestore.instance;

  var enablePersistence = true;

  if (kIsWeb) {
    final uri = Uri.base;
    final host = uri.host.toLowerCase();
    final insecure = uri.scheme != 'https';

    final isLocalDev =
        host == 'localhost' || host == '127.0.0.1' || host.endsWith('.local');

    // 🔥 CRITICAL: disable persistence on localhost web
    if (isLocalDev || insecure) {
      enablePersistence = false;
    }
  }

  try {
    fs.settings = Settings(persistenceEnabled: enablePersistence);

    BootLog.d(
      'Firestore persistence: ${enablePersistence ? 'ON' : 'OFF'} '
      '(platform=${kIsWeb ? 'web' : 'mobile'} origin=${kIsWeb ? Uri.base.origin : '-'})',
    );
  } catch (e) {
    // Happens if Firestore already initialized — safe to ignore
    BootLog.e('Firestore settings skipped: $e');
  }
}

/// ─────────────────────────────────────────────
/// Firebase info logging
/// ─────────────────────────────────────────────

void _logFirebaseAppInfo(bool emulatorEnabled) {
  final o = Firebase.app().options;

  String mask(String? v) =>
      (v == null || v.length < 8) ? '-' : '${v.substring(0, 6)}…';

  final origin = kIsWeb ? Uri.base.origin : 'app';

  BootLog.d(
    '[AuthCFG] projectId=${o.projectId} '
    'appId=${o.appId} '
    'apiKey=${mask(o.apiKey)} '
    'authDomain=${o.authDomain ?? '-'} '
    'origin=$origin '
    'authEmulator=${emulatorEnabled ? 'ON' : 'OFF'}',
  );
}
