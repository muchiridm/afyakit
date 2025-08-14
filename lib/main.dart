import 'package:afyakit/shared/providers/tenant_config_provider.dart';
import 'package:afyakit/shared/utils/decide_tenant.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart'; // used only on web
import 'package:afyakit/users/services/firebase_auth_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/providers/tenant_id_provider.dart';

import 'package:afyakit/shared/config/tenant_config.dart';

import 'package:afyakit/users/widgets/auth_gate.dart';
import 'package:afyakit/users/screens/invite_accept_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Android/iOS flavor default (passed at build time). Web ignores this.
const kDefaultTenant = String.fromEnvironment(
  'TENANT',
  defaultValue: 'afyakit',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 App starting...');

  // ✅ Firebase init
  if (kIsWeb) {
    debugPrint('🌐 Web → Firebase with explicit options');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    debugPrint('📱 Mobile/Desktop → Firebase default config');
    await Firebase.initializeApp();
  }
  debugPrint('✅ Firebase initialized');

  final uri = Uri.base;
  final uid = uri.queryParameters['uid'];
  final isInviteFlow = uri.path == '/invite/accept' && uid != null;

  // Resolve tenant id
  // Resolve tenant id (query → TENANT define → domain → fallback)
  final tenant = decideTenant();
  debugPrint('🏢 Using tenant: $tenant');

  // 🔹 Load the tenant config JSON before bootstrapping widgets
  TenantConfig cfg;
  try {
    cfg = await loadTenantConfig(tenant);
  } catch (e) {
    debugPrint(
      '⚠️ Failed to load config for $tenant → falling back to afyakit. Error: $e',
    );
    cfg = await loadTenantConfig('afyakit');
  }

  // Provide tenant id + loaded config globally
  final container = ProviderContainer(
    overrides: [
      tenantIdProvider.overrideWithValue(tenant),
      tenantConfigProvider.overrideWithValue(cfg),
    ],
  );

  // Wait for Firebase Auth to restore session
  final auth = container.read(firebaseAuthServiceProvider);
  await auth.waitForUser();

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
