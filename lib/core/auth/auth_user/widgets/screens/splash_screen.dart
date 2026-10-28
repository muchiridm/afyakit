import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/app_identity.dart';
import 'package:afyakit/app/providers/app_profile_provider.dart';
import 'package:afyakit/core/branding/providers/app_logo_providers.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  static const double _logoSize = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final appProfileAsync = ref.watch(appProfileProvider);

    // Splash uses the SECONDARY logo.
    final logoAsync = ref.watch(appSecondaryLogoUrlProvider);

    final displayName = appProfileAsync.maybeWhen(
      data: (profile) {
        final name = profile.displayName.trim();
        return name.isNotEmpty ? name : profile.id;
      },
      orElse: () => AppIdentity.appId,
    );

    final primary = appProfileAsync.maybeWhen(
      data: (profile) => profile.primaryColor,
      orElse: () => theme.colorScheme.primary,
    );

    final availableWidth = MediaQuery.sizeOf(context).width - 48;
    final logoSize = availableWidth.clamp(0.0, _logoSize);

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBrand(
              theme: theme,
              displayName: displayName,
              logoAsync: logoAsync,
              primary: primary,
              logoSize: logoSize,
            ),
            const SizedBox(height: 32),
            _buildSpinner(),
            const SizedBox(height: 12),
            _buildLoadingText(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBrand({
    required ThemeData theme,
    required String displayName,
    required AsyncValue<String?> logoAsync,
    required Color primary,
    required double logoSize,
  }) {
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

    Widget logoLoading() {
      return SizedBox(
        width: logoSize,
        height: logoSize,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
      );
    }

    return logoAsync.when(
      loading: logoLoading,

      error: (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ [splash-logo] Secondary logo lookup failed: $error');
        }

        return placeholder();
      },

      data: (url) {
        final logoUrl = url?.trim() ?? '';

        if (logoUrl.isEmpty) {
          if (kDebugMode) {
            debugPrint(
              '⚠️ [splash-logo] Secondary logo missing; '
              'showing fallback: $displayName',
            );
          }

          return placeholder();
        }

        return ClipRRect(
          borderRadius: radius,
          child: Image.network(
            logoUrl,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,

            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                debugPrint('❌ [splash-logo] Secondary image failed: $error');
              }

              return placeholder();
            },

            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              return logoLoading();
            },
          ),
        );
      },
    );
  }

  Widget _initialsBlock({
    required String displayName,
    required Color primary,
    required BorderRadius radius,
    required double size,
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

    if (parts.isEmpty) return '';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _buildSpinner() {
    return const SizedBox(
      width: 32,
      height: 32,
      child: CircularProgressIndicator.adaptive(strokeWidth: 2.4),
    );
  }

  Widget _buildLoadingText(ThemeData theme) {
    return Text(
      'Loading...',
      style: theme.textTheme.labelMedium?.copyWith(
        fontSize: 12,
        color: theme.hintColor.withValues(alpha: 0.9),
        letterSpacing: 0.2,
      ),
    );
  }
}
