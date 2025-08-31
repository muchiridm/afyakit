import 'package:afyakit/hq/core/tenants/providers/tenant_providers.dart';
import 'package:afyakit/hq/core/tenants/utils/color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/core/auth_users/widgets/auth_gate.dart';
import 'package:afyakit/core/auth_users/screens/invite_accept_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
