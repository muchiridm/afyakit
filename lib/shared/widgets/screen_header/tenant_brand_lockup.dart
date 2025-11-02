// lib/shared/widgets/screen_header/tenant_brand_lockup.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/widgets/screen_header/tenant_logo.dart';
import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';

class TenantBrandLockup extends ConsumerWidget {
  final double height;
  final bool showName;
  final EdgeInsets padding;
  final double? nameFontSize;
  final bool useChip; // 👈 NEW

  const TenantBrandLockup({
    super.key,
    this.height = 28,
    this.showName = true,
    this.padding = const EdgeInsets.all(6),
    this.nameFontSize,
    this.useChip = true, // 👈 keep old behavior
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(tenantConfigProvider);
    final theme = Theme.of(context);

    final double scaledFs = (height * 0.58).clamp(16, 32);
    final double fs = nameFontSize ?? scaledFs;

    final chipBg = theme.colorScheme.surfaceContainerHighest.withOpacity(
      theme.brightness == Brightness.dark ? 0.35 : 0.55,
    );

    final logo = TenantLogo(height: height - (useChip ? padding.vertical : 0));

    Widget logoPart;
    if (useChip) {
      logoPart = Container(
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.25),
            width: 0.75,
          ),
        ),
        child: Center(child: logo),
      );
    } else {
      // plain logo, no card
      logoPart = SizedBox(
        height: height,
        child: Align(alignment: Alignment.centerLeft, child: logo),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoPart,
        if (showName) ...[
          const SizedBox(width: 12),
          Text(
            cfg.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: fs,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ],
    );
  }
}
