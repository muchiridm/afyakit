import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/hq/tenants/utils/color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/core/auth_users/widgets/auth_gate.dart';
import 'package:afyakit/core/auth_users/screens/invite_accept_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Debug logger (no-op in release).
class Log {
  static void d(String msg) {
    if (kDebugMode) debugPrint('🧭 $msg');
  }
}

/// Logs all navigator mutations so we can see stack behavior.
class RouteLogger extends NavigatorObserver {
  String _label(Route<dynamic>? r) {
    if (r == null) return '∅';
    final name = r.settings.name ?? '∅';
    final type = r.runtimeType.toString();
    final id = identityHashCode(r).toRadixString(16);
    return '$name [$type@$id]';
  }

  void _p(String what, Route<dynamic>? r, [Route<dynamic>? p]) {
    Log.d(
      'NAV ${what.padRight(7)} → ${_label(r)}'
      '${p != null ? '  prev=${_label(p)}' : ''}',
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _p('push', route, previousRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _p('pop', route, previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _p('remove', route, previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _p('replace', newRoute, oldRoute);
}

// One shared instance to avoid duplicate observer spam across rebuilds.
final RouteLogger _routeLogger = RouteLogger();

class AfyaKitApp extends ConsumerWidget {
  final bool isInviteFlow;
  final Map<String, String>? inviteParams;

  const AfyaKitApp({super.key, required this.isInviteFlow, this.inviteParams});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(tenantConfigProvider);

    // Decide the first visible page. Avoid stringifying the widget in logs.
    final Widget root = isInviteFlow
        ? ((inviteParams == null || inviteParams!.isEmpty)
              ? const _BadInviteScreen()
              : InviteAcceptScreen(inviteParams: inviteParams!))
        : const AuthGate();

    return MaterialApp(
      title: cfg.displayName,
      // Optional: helps state restoration if you later adopt it
      restorationScopeId: 'afyakit-root',
      debugShowCheckedModeBanner: false,

      navigatorKey: navigatorKey,
      scaffoldMessengerKey: SnackService.scaffoldMessengerKey,

      // 🔒 Hard-seed the initial stack regardless of browser URL.
      onGenerateInitialRoutes: (String initial) {
        Log.d(
          'onGenerateInitialRoutes(initial="$initial") → seed ${root.runtimeType}',
        );
        return <Route<dynamic>>[
          MaterialPageRoute(
            builder: (_) => root,
            settings: const RouteSettings(name: '/'),
          ),
        ];
      },

      // 🔒 Any later named navigation we haven't mapped still lands on `root`.
      onGenerateRoute: (RouteSettings settings) {
        Log.d('onGenerateRoute("${settings.name}") → ${root.runtimeType}');
        return MaterialPageRoute(builder: (_) => root, settings: settings);
      },

      // 🔒 Never return null.
      onUnknownRoute: (settings) {
        Log.d('onUnknownRoute("${settings.name}") → _NotFoundScreen');
        return MaterialPageRoute(
          builder: (_) => const _NotFoundScreen(),
          settings: settings,
        );
      },

      // 👀 Observe every route change.
      navigatorObservers: [_routeLogger],

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorFromHex(cfg.primaryColorHex),
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}

class _BadInviteScreen extends StatelessWidget {
  const _BadInviteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_off, size: 56),
              const SizedBox(height: 12),
              const Text(
                'Invalid or incomplete invite link.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please request a fresh invite or try opening the link again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Route not found')));
  }
}
