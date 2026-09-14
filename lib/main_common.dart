// lib/main_common.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';

import 'package:afyakit/app/app_mode.dart';
import 'package:afyakit/app/app_root.dart';
import 'package:afyakit/core/hq/domains/services/domain_tenant_resolver.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/shared/debug/riverpod_logger.dart';

final authEmulatorEnabledProvider = Provider<bool>((_) => false);

final class BootLog {
  static void d(String message) => debugPrint('🚀 $message');

  static void e(String message) => debugPrint('💥 $message');
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  BootLog.d(
    'Background notification '
    'messageId=${message.messageId ?? '-'} '
    'type=${message.data['type'] ?? '-'}',
  );
}

Future<void> bootstrapAndRun({
  required String defaultTenantId,
  AppMode appMode = AppMode.tenant,
}) async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _installGlobalErrorHandlers();

      BootLog.d('Initializing Firebase…');

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final bool usingAuthEmulator = await _configureAuthForDev();

      _logFirebaseAppInfo(usingAuthEmulator);

      await _configureFirestoreForPlatform();

      final String resolvedTenantId;

      if (appMode == AppMode.tenant) {
        resolvedTenantId = await resolveTenantIdAsync(
          defaultId: defaultTenantId,
        );

        BootLog.d('Using tenant: $resolvedTenantId');
      } else {
        resolvedTenantId = defaultTenantId;

        BootLog.d(
          'Running in HQ mode '
          '(tenantId=$resolvedTenantId)',
        );
      }

      runApp(
        ProviderScope(
          observers: const [RiverpodLogger()],
          overrides: [
            authEmulatorEnabledProvider.overrideWithValue(usingAuthEmulator),
            tenantIdProvider.overrideWithValue(resolvedTenantId),
          ],
          child: AppRoot(mode: appMode),
        ),
      );
    },
    (Object error, StackTrace stackTrace) {
      BootLog.e('ZoneError: $error');
      debugPrintStack(stackTrace: stackTrace);
    },
  );
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    BootLog.e('FlutterError: ${details.exceptionAsString()}');

    final StackTrace? stackTrace = details.stack;

    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    BootLog.e('PlatformDispatcherError: $error');
    debugPrintStack(stackTrace: stackTrace);

    return true;
  };
}

Future<bool> _configureAuthForDev() async {
  if (!kDebugMode) return false;

  const bool useEmulator = bool.fromEnvironment(
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

  const String host = String.fromEnvironment(
    'AUTH_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  const int port = int.fromEnvironment(
    'AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );

  await fb.FirebaseAuth.instance.useAuthEmulator(host, port);

  try {
    await fb.FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  } catch (_) {}

  BootLog.d(
    'Firebase Auth emulator ENABLED '
    'at http://$host:$port',
  );

  return true;
}

Future<void> _configureFirestoreForPlatform() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool enablePersistence = true;

  if (kIsWeb) {
    final Uri uri = Uri.base;
    final String host = uri.host.toLowerCase();

    final bool insecure = uri.scheme != 'https';

    final bool isLocalDevelopment =
        host == 'localhost' || host == '127.0.0.1' || host.endsWith('.local');

    if (isLocalDevelopment || insecure) {
      enablePersistence = false;
    }
  }

  try {
    firestore.settings = Settings(persistenceEnabled: enablePersistence);

    BootLog.d(
      'Firestore persistence: '
      '${enablePersistence ? 'ON' : 'OFF'} '
      '(platform=${kIsWeb ? 'web' : 'mobile'} '
      'origin=${kIsWeb ? Uri.base.origin : '-'})',
    );
  } catch (error) {
    BootLog.e('Firestore settings skipped: $error');
  }
}

void _logFirebaseAppInfo(bool emulatorEnabled) {
  final FirebaseOptions options = Firebase.app().options;

  String mask(String? value) {
    if (value == null || value.length < 8) {
      return '-';
    }

    return '${value.substring(0, 6)}…';
  }

  final String origin = kIsWeb ? Uri.base.origin : 'app';

  BootLog.d(
    '[AuthCFG] '
    'projectId=${options.projectId} '
    'appId=${options.appId} '
    'apiKey=${mask(options.apiKey)} '
    'authDomain=${options.authDomain ?? '-'} '
    'origin=$origin '
    'authEmulator=${emulatorEnabled ? 'ON' : 'OFF'}',
  );
}
