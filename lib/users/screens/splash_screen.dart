import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/providers/tenant_config_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // per-tenant
    final cfg = ref.watch(tenantConfigProvider);
    final displayName = cfg.displayName;
    final logoPath = cfg.logoPath; // ← nullable
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBrand(
              theme: theme,
              displayName: displayName,
              logoPath: logoPath,
              primary: primary,
            ),
            const SizedBox(height: 8),
            _buildSpinner(),
            const SizedBox(height: 16),
            _buildLoadingText(theme),
          ],
        ),
      ),
    );
  }

  // ── private builders ────────────────────────────────────────────────────────

  Widget _buildBrand({
    required ThemeData theme,
    required String displayName,
    required String? logoPath, // ← allow null
    required Color primary,
  }) {
    final titleStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: primary,
    );

    final hasLogo = logoPath != null && logoPath.trim().isNotEmpty;
    final radius = BorderRadius.circular(8);

    Widget logoWidget() {
      if (!hasLogo) {
        return Icon(Icons.local_hospital, size: 48, color: primary);
      }

      final path = logoPath.trim();
      final isNetwork =
          path.startsWith('http://') || path.startsWith('https://');

      final img = isNetwork
          ? Image.network(
              path,
              height: 56,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.local_hospital, size: 48, color: primary),
            )
          : Image.asset(
              path,
              height: 56,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.local_hospital, size: 48, color: primary),
            );

      return ClipRRect(borderRadius: radius, child: img);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
          logoWidget(),
          const SizedBox(height: 8),
          Text(displayName, style: titleStyle),
        ],
      ),
    );
  }

  Widget _buildSpinner() {
    return const SizedBox(
      width: 32,
      height: 32,
      child: CircularProgressIndicator.adaptive(),
    );
  }

  Widget _buildLoadingText(ThemeData theme) {
    // hintColor can be low-contrast in dark mode; tweak if needed
    final color = theme.hintColor;
    return Text(
      'Loading...',
      style: theme.textTheme.bodyMedium?.copyWith(color: color),
    );
  }
}
