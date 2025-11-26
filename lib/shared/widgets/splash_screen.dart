import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/hq/tenants/providers/tenant_logo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final profile = ref.watch(tenantProfileProvider);
    final logoUrl = ref.watch(tenantSecondaryLogoUrlProvider);
    final displayName = profile.displayName;
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
              logoUrl: logoUrl,
              primary: primary,
            ),
            const SizedBox(height: 24),
            _buildSpinner(),
            const SizedBox(height: 8),
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
    required String? logoUrl,
    required Color primary,
  }) {
    const double logoSize = 140.0;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: primary,
    );

    final hasLogo = logoUrl != null && logoUrl.trim().isNotEmpty;
    final radius = BorderRadius.circular(16);

    Widget logoWidget() {
      if (!hasLogo) {
        return Icon(Icons.local_hospital, size: logoSize, color: primary);
      }

      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          logoUrl,
          height: logoSize,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.local_hospital, size: logoSize, color: primary),
        ),
      );
    }

    return Column(
      children: [
        logoWidget(),
        const SizedBox(height: 12),
        Text(displayName, style: titleStyle, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildSpinner() {
    return const SizedBox(
      width: 32,
      height: 32,
      child: CircularProgressIndicator.adaptive(strokeWidth: 2.4),
    );
  }

  Widget _buildLoadingText(ThemeData theme) {
    final color = theme.hintColor.withOpacity(0.9);
    return Text(
      'Loading...',
      style: theme.textTheme.labelMedium?.copyWith(
        fontSize: 12,
        color: color,
        letterSpacing: 0.2,
      ),
    );
  }
}
