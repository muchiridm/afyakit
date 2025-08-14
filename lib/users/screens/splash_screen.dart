import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/providers/tenant_config_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // per-tenant
    final cfg = ref.watch(tenantConfigProvider);
    final displayName = cfg.displayName;
    final logoAsset = cfg.logoAsset;

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBrand(
              theme: theme,
              displayName: displayName,
              logoAsset: logoAsset,
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
    required String logoAsset,
  }) {
    final titleStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.primary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
          if (logoAsset.isNotEmpty)
            Image.asset(
              logoAsset,
              height: 56,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.local_hospital,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            )
          else
            Icon(
              Icons.local_hospital,
              size: 48,
              color: theme.colorScheme.primary,
            ),
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
    return Text(
      'Loading...',
      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
    );
  }
}
