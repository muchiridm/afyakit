import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/branding/providers/app_logo_providers.dart';

enum AppBrandLogoSize { compact, header, large, hero }

extension AppBrandLogoSizeX on AppBrandLogoSize {
  double get height => switch (this) {
    AppBrandLogoSize.compact => 44,
    AppBrandLogoSize.header => 64,
    AppBrandLogoSize.large => 76,
    AppBrandLogoSize.hero => 92,
  };

  double get maxWidth => switch (this) {
    AppBrandLogoSize.compact => 180,
    AppBrandLogoSize.header => 300,
    AppBrandLogoSize.large => 340,
    AppBrandLogoSize.hero => 420,
  };
}

/// Displays the primary logo of the currently booted app.
///
/// Storage path:
/// public/{tenantId}/{appId}/branding/logos/logo-primary.png
class AppBrandLogo extends ConsumerWidget {
  const AppBrandLogo({
    super.key,
    this.size = AppBrandLogoSize.header,
    this.height,
    this.maxWidth,
    this.fallbackLabel = 'AfyaKit',
  });

  final AppBrandLogoSize size;

  /// Overrides [size.height] when provided.
  final double? height;

  /// Overrides [size.maxWidth] when provided.
  final double? maxWidth;

  /// Displayed when the logo is missing or cannot be loaded.
  final String fallbackLabel;

  double get _effectiveHeight => height ?? size.height;

  double get _effectiveMaxWidth => maxWidth ?? size.maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoAsync = ref.watch(appPrimaryLogoUrlProvider);

    final effectiveHeight = _effectiveHeight;
    final effectiveMaxWidth = _effectiveMaxWidth;

    Widget fallback() => _LogoFallback(
      height: effectiveHeight,
      maxWidth: effectiveMaxWidth,
      label: fallbackLabel,
    );

    Widget loading() => SizedBox(
      height: effectiveHeight,
      width: effectiveMaxWidth,
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );

    return logoAsync.when(
      loading: loading,

      error: (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ [app-logo] Provider error: $error');
        }

        return fallback();
      },

      data: (url) {
        final logoUrl = url?.trim() ?? '';

        if (logoUrl.isEmpty) {
          if (kDebugMode) {
            debugPrint(
              '⚠️ [app-logo] No primary logo URL; '
              'showing fallback: $fallbackLabel',
            );
          }

          return fallback();
        }

        return SizedBox(
          height: effectiveHeight,
          width: effectiveMaxWidth,
          child: Center(
            child: Image.network(
              logoUrl,
              height: effectiveHeight,
              width: effectiveMaxWidth,
              fit: BoxFit.contain,

              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  debugPrint('❌ [app-logo] Image.network failed: $error');
                }

                return fallback();
              },

              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return loading();
              },
            ),
          ),
        );
      },
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({
    required this.height,
    required this.maxWidth,
    required this.label,
  });

  final double height;
  final double maxWidth;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      width: maxWidth,
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
