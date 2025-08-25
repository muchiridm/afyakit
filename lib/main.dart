import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/features/tenants/utils/tenant_picker.dart'; // decideTenant()
import 'package:afyakit/features/tenants/services/tenant_loader.dart'; // loadTenantConfig
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

  // Firestore (safe on all platforms)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  debugPrint('✅ Firebase initialized');

  // URL/deeplink bits
  final uri = Uri.base;
  final segs = uri.pathSegments;
  final uid = uri.queryParameters['uid'];
  final isInviteFlow =
      segs.length >= 2 &&
      segs[0] == 'invite' &&
      segs[1] == 'accept' &&
      uid != null;

  // Tenant
  final tenant = decideTenant(); // ?tenant=, host, path, else fallback
  debugPrint('🏢 Using tenant: $tenant');

  // Load tenant config (backend if available → asset → default)
  final cfg = await loadTenantConfig(
    tenant,
    tokenProvider: null, // no token at boot; loader goes public
    preferBackend: true, // try API unauth first (no warnings)
    assetFallback: 'afyakit', // safety net
  );

  // Provide tenant id + config into the root container
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
        inviteParams: isInviteFlow ? {'tenant': tenant, 'uid': uid} : null,
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
