// lib/core/hq/branding/widgets/tenant_brand_logo.dart

import 'package:afyakit/core/hq/branding/providers/tenant_logo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TenantBrandLogoSize { compact, header, large, hero }

extension TenantBrandLogoSizeX on TenantBrandLogoSize {
  double get height {
    return switch (this) {
      TenantBrandLogoSize.compact => 44,
      TenantBrandLogoSize.header => 64,
      TenantBrandLogoSize.large => 76,
      TenantBrandLogoSize.hero => 92,
    };
  }

  double get maxWidth {
    return switch (this) {
      TenantBrandLogoSize.compact => 180,
      TenantBrandLogoSize.header => 300,
      TenantBrandLogoSize.large => 340,
      TenantBrandLogoSize.hero => 420,
    };
  }
}

class TenantBrandLogo extends ConsumerWidget {
  const TenantBrandLogo({
    super.key,
    this.size = TenantBrandLogoSize.header,
    this.height,
    this.maxWidth,
    this.fallbackLabel = 'AfyaKit',
  });

  /// Named size preset.
  ///
  /// Use this for most cases.
  final TenantBrandLogoSize size;

  /// Optional explicit override.
  ///
  /// If provided, this wins over [size.height].
  final double? height;

  /// Optional explicit override.
  ///
  /// If provided, this wins over [size.maxWidth].
  final double? maxWidth;

  final String fallbackLabel;

  double get _effectiveHeight => height ?? size.height;
  double get _effectiveMaxWidth => maxWidth ?? size.maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoUrl = ref.watch(tenantPrimaryLogoUrlProvider).trim();

    final effectiveHeight = _effectiveHeight;
    final effectiveMaxWidth = _effectiveMaxWidth;

    if (logoUrl.isEmpty) {
      return _LogoFallback(
        height: effectiveHeight,
        maxWidth: effectiveMaxWidth,
        label: fallbackLabel,
      );
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
          errorBuilder: (_, __, ___) => _LogoFallback(
            height: effectiveHeight,
            maxWidth: effectiveMaxWidth,
            label: fallbackLabel,
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;

            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
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
