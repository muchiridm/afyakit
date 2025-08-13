import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'package:afyakit/users/services/firebase_auth_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/providers/tenant_provider.dart';

import 'package:afyakit/users/widgets/auth_gate.dart';
import 'package:afyakit/users/screens/invite_accept_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ Firebase initialized');

  final uri = Uri.base;

  // 🌍 Extract tenant and uid from URL (invite flow)
  final tenant = uri.queryParameters['tenant'] ?? 'danabtmc'; // fallback
  final uid = uri.queryParameters['uid'];
  final isInviteFlow = uri.path == '/invite/accept' && uid != null;

  final container = ProviderContainer(
    overrides: [tenantIdProvider.overrideWithValue(tenant)],
  );

  // ⏳ Wait for Firebase Auth session to restore
  final auth = container.read(firebaseAuthServiceProvider);
  await auth.waitForUser();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: DanabTMCApp(
        isInviteFlow: isInviteFlow,
        inviteParams: isInviteFlow ? {'tenant': tenant, 'uid': uid} : null,
      ),
    ),
  );
}

class DanabTMCApp extends StatelessWidget {
  final bool isInviteFlow;
  final Map<String, String>? inviteParams;

  const DanabTMCApp({
    super.key,
    required this.isInviteFlow,
    required this.inviteParams,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Danab TMC Portal',
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
