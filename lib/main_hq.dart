// lib/main_hq.dart
import 'dart:ui'; // PlatformDispatcher
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/firebase_options.dart';
import 'package:afyakit/app/hq_app.dart';
import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/hq/core/tenants/services/tenant_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = FlutterError.dumpErrorToConsole;
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('UNHANDLED (HQ): $error\n$stack');
    return false;
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    '⚙️ Firebase project: ${DefaultFirebaseOptions.currentPlatform.projectId}',
  );

  // Debug-only, sanitized claim logging
  assert(() {
    fb.FirebaseAuth.instance.idTokenChanges().listen((u) async {
      if (u == null) {
        debugPrint('🔐 [HQ][dbg] user=null');
        return;
      }
      try {
        final t = await u.getIdTokenResult(true); // force refresh
        final c = t.claims ?? const <String, dynamic>{};
        final superadmin = c['superadmin'] == true;
        final tenant = (c['tenantId'] ?? c['tenant'])?.toString();
        debugPrint(
          '🔐 [HQ][dbg] uid=${u.uid} email=${u.email} super=$superadmin tenant=$tenant',
        );
      } catch (e, st) {
        debugPrint('🔐 [HQ][dbg] failed to fetch claims: $e\n$st');
      }
    });
    return true;
  }());

  const hqConfig = TenantConfig(
    id: 'hq',
    displayName: 'AfyaKit HQ',
    primaryColorHex: '#1565C0',
  );

  runApp(
    ProviderScope(
      overrides: [
        tenantIdProvider.overrideWithValue('hq'),
        tenantConfigProvider.overrideWithValue(hqConfig),
      ],
      child: const HqApp(),
    ),
  );
}
