// lib/core/auth_users/widgets/screens/splash_screen.dart
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/branding/providers/tenant_logo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use display-name provider so we never show "Loading…"
    final displayName = ref.watch(tenantDisplayNameProvider);
    final logoUrl = ref.watch(tenantSecondaryLogoUrlProvider);
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
    final hasUrl = logoUrl != null && logoUrl.trim().isNotEmpty;
    final radius = BorderRadius.circular(16);

    // Placeholder: initials block + app name
    Widget placeholder() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _initialsBlock(
            displayName: displayName,
            primary: primary,
            radius: radius,
            size: logoSize,
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // No URL at all → placeholder + name
    if (!hasUrl) {
      return placeholder();
    }

    // URL present → try to load; on error fallback to placeholder
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        logoUrl,
        height: logoSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => placeholder(),
      ),
    );
  }

  Widget _initialsBlock({
    required String displayName,
    required Color primary,
    required BorderRadius radius,
    double size = 140.0,
  }) {
    final initials = _initialsFromName(displayName);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary.withOpacity(0.12),
        borderRadius: radius,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
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
