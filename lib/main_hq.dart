import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/firebase_options.dart';
import 'package:afyakit/app/hq_app.dart';

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

  // Debug-only logging
  assert(() {
    fb.FirebaseAuth.instance.idTokenChanges().listen((u) async {
      if (u == null) {
        debugPrint('🔐 [HQ] user=null');
        return;
      }
      try {
        final t = await u.getIdTokenResult(true);
        final c = t.claims ?? const <String, dynamic>{};
        debugPrint(
          '🔐 [HQ] uid=${u.uid} email=${u.email} hq=${c['hq'] == true}',
        );
      } catch (e, st) {
        debugPrint('🔐 [HQ] failed to fetch claims: $e\n$st');
      }
    });
    return true;
  }());

  runApp(const ProviderScope(child: HqApp()));
}
