import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart'; // used only on web
import 'package:afyakit/users/services/firebase_auth_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/providers/tenant_id_provider.dart';

import 'package:afyakit/users/widgets/auth_gate.dart';
import 'package:afyakit/users/screens/invite_accept_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Android/iOS flavor default (passed at build time). Web ignores this.
const kDefaultTenant = String.fromEnvironment(
  'TENANT',
  defaultValue: 'danabtmc',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 App starting...');

  // ✅ Firebase init: web uses explicit options, native reads google-services.json
  if (kIsWeb) {
    debugPrint(
      '🌐 Running on Web → Initializing Firebase with explicit options',
    );
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    debugPrint(
      '📱 Running on Mobile/Desktop → Initializing Firebase with default config',
    );
    await Firebase.initializeApp();
  }
  debugPrint('✅ Firebase initialized');

  final uri = Uri.base;
  debugPrint('🔍 Current URI: $uri');

  // Invite flow (query param wins)
  final inviteTenant = uri.queryParameters['tenant'];
  final uid = uri.queryParameters['uid'];
  final isInviteFlow = uri.path == '/invite/accept' && uid != null;

  debugPrint('📩 Invite tenant param: $inviteTenant');
  debugPrint('👤 Invite UID param: $uid');
  debugPrint('🔄 Is invite flow? $isInviteFlow');

  // Tenant resolution
  final tenant = (inviteTenant ?? (kIsWeb ? resolveTenantId() : kDefaultTenant))
      .toLowerCase();

  debugPrint('🏢 Resolved tenant: $tenant');
  debugPrint('📦 Default tenant (kDefaultTenant): $kDefaultTenant');

  // Provide the tenant globally
  final container = ProviderContainer(
    overrides: [tenantIdProvider.overrideWithValue(tenant)],
  );
  debugPrint('📦 ProviderContainer created with tenant: $tenant');

  // Wait for Firebase Auth to restore session
  final auth = container.read(firebaseAuthServiceProvider);
  debugPrint('⏳ Waiting for Firebase Auth user session restore...');
  await auth.waitForUser();
  debugPrint('✅ Firebase Auth session ready');

  // Launch app
  debugPrint('🚀 Launching AfyaKitApp...');
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

  String _titleFor(String tenant) {
    switch (tenant) {
      case 'danabtmc':
        return 'Danab TMC';
      case 'dawapap':
        return 'DawaPap';
      default:
        return 'AfyaKit';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantIdProvider);
    final appTitle = _titleFor(tenant);

    return MaterialApp(
      title: appTitle, // ✅ dynamic per-tenant
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: isInviteFlow
          ? InviteAcceptScreen(inviteParams: inviteParams!)
          : const AuthGate(),
    );
  }
}
