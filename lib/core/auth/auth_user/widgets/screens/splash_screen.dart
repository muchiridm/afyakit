// lib/core/auth_users/widgets/screens/splash_screen.dart

import 'package:afyakit/app/app_identity.dart';
import 'package:afyakit/app/providers/app_profile_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final appProfileAsync = ref.watch(appProfileProvider);

    final displayName = appProfileAsync.maybeWhen(
      data: (profile) {
        final name = profile.displayName.trim();

        return name.isNotEmpty ? name : profile.id;
      },
      orElse: () => AppIdentity.appId,
    );

    final logoUrl = appProfileAsync.maybeWhen<String?>(
      data: (profile) => profile.logoUrl(),
      orElse: () => null,
    );

    final primary = appProfileAsync.maybeWhen(
      data: (profile) => profile.primaryColor,
      orElse: () => theme.colorScheme.primary,
    );

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

  // ─────────────────────────────────────────────
  // Brand
  // ─────────────────────────────────────────────

  Widget _buildBrand({
    required ThemeData theme,
    required String displayName,
    required String? logoUrl,
    required Color primary,
  }) {
    const logoSize = 140.0;

    final cleanLogoUrl = logoUrl?.trim();

    final hasLogo = cleanLogoUrl != null && cleanLogoUrl.isNotEmpty;

    final radius = BorderRadius.circular(16);

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

    if (!hasLogo) {
      return placeholder();
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        cleanLogoUrl,
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
        color: primary.withValues(alpha: 0.12),
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
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // ─────────────────────────────────────────────
  // Loading
  // ─────────────────────────────────────────────

  Widget _buildSpinner() {
    return const SizedBox(
      width: 32,
      height: 32,
      child: CircularProgressIndicator.adaptive(strokeWidth: 2.4),
    );
  }

  Widget _buildLoadingText(ThemeData theme) {
    final color = theme.hintColor.withValues(alpha: 0.9);

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
