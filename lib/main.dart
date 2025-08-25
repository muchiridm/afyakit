// lib/main.dart
import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/features/tenants/services/tenant_resolver.dart'; // resolveTenantSlug()
import 'package:afyakit/features/tenants/services/tenant_loader.dart'; // TenantConfigLoader
import 'package:afyakit/features/tenants/services/tenant_config.dart'; // TenantConfig + color

import 'package:afyakit/features/auth_users/providers/user_operations_engine_providers.dart';
import 'package:afyakit/features/auth_users/widgets/auth_gate.dart';
import 'package:afyakit/features/auth_users/screens/invite_accept_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 App starting...');

  // Firebase init
  if (kIsWeb) {
    debugPrint('🌐 Web → Firebase with explicit options');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }

  // Firestore settings (safe on all platforms)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  debugPrint('✅ Firebase initialized');

  // URL / deeplink parsing
  final uri = Uri.base;
  final segs = uri.pathSegments;
  final uid = uri.queryParameters['uid'];
  final bool isInviteFlow =
      segs.length >= 2 &&
      segs[0] == 'invite' &&
      segs[1] == 'accept' &&
      uid != null;

  // ── Tenant resolution (domain → slug, with ?tenant= override) ───────────────
  final String tenant = resolveTenantSlug(defaultSlug: 'afyakit');
  debugPrint('🏢 Using tenant: $tenant');

  // ── Firestore-only tenant config load (no assets, no API hop) ───────────────
  final loader = TenantConfigLoader(FirebaseFirestore.instance);
  late final TenantConfig cfg;
  try {
    cfg = await loader.load(
      tenant,
    ); // throws if not found/suspended and no cache
  } catch (e, st) {
    debugPrint('❌ Tenant config load failed: $e\n$st');
    runApp(const _ErrorApp(message: 'Unable to load tenant configuration.'));
    return;
  }

  // ── Provide tenant id + config into the root container ─────────────────────
  final container = ProviderContainer(
    overrides: [
      tenantIdProvider.overrideWithValue(tenant),
      tenantConfigProvider.overrideWithValue(cfg),
    ],
  );

  // Pre-hydrate auth session (non-blocking)
  try {
    final engine = await container.read(sessionEngineProvider(tenant).future);
    await engine.ensureReady();
  } catch (e) {
    debugPrint('⚠️ Session pre-hydration failed: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: AfyaKitApp(
        isInviteFlow: isInviteFlow,
        inviteParams: isInviteFlow
            ? <String, String>{'tenant': tenant, 'uid': uid}
            : null,
      ),
    ),
  );
}

class AfyaKitApp extends ConsumerWidget {
  final bool isInviteFlow;
  final Map<String, String>? inviteParams;

  const AfyaKitApp({super.key, required this.isInviteFlow, this.inviteParams});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(tenantConfigProvider);

    return MaterialApp(
      title: cfg.displayName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorFromHex(cfg.primaryColorHex),
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: isInviteFlow
          ? InviteAcceptScreen(inviteParams: inviteParams!)
          : const AuthGate(),
    );
  }
}

class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
