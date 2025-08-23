import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/features/tenants/providers/tenant_config_provider.dart';
import 'package:afyakit/shared/utils/decide_tenant.dart';
import 'package:afyakit/features/tenants/services/tenant_loader.dart';
import 'package:afyakit/features/auth_users/user_operations/providers/user_operations_engine_providers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';

import 'package:afyakit/config/tenant_config.dart';

import 'package:afyakit/features/auth_users/widgets/auth_gate.dart';
import 'package:afyakit/features/auth_users/screens/invite_accept_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Android/iOS flavor default (passed at build time). Web ignores this.
const kDefaultTenant = String.fromEnvironment(
  'TENANT',
  defaultValue: 'afyakit',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 App starting...');

  // Firebase init
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }

  // ✅ new: set settings once, any platform
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  final uri = Uri.base;
  final uid = uri.queryParameters['uid'];
  final isInviteFlow = uri.path == '/invite/accept' && uid != null;

  // Resolve tenant
  final tenant = decideTenant();
  debugPrint('🏢 Using tenant: $tenant');

  // Single call: loader handles Firestore → asset → default fallback + logs
  final cfg = await loadTenantConfig(tenant);

  // Provide tenant id + loaded config globally
  final container = ProviderContainer(
    overrides: [
      tenantIdProvider.overrideWithValue(tenant),
      tenantConfigProvider.overrideWithValue(cfg),
    ],
  );

  // Build the engine and do one clean pre-hydration (fast enough in practice).
  final sessionEngine = await container.read(
    sessionEngineProvider(tenant).future,
  );
  try {
    // ensureReady(): waitForUser + claims check + backend checkUserStatus()
    await sessionEngine.ensureReady();
  } catch (e) {
    // Don’t block startup on failures; AuthGate will still handle state.
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
    final cfg = ref.watch(
      tenantConfigProvider,
    ); // ✅ already loaded at bootstrap

    return MaterialApp(
      title: cfg.displayName, // ✅ per-tenant title
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
