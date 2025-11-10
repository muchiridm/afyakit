import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/v2/providers/tenant_logo_providers.dart';
import 'package:afyakit/core/auth_users/guards/require_auth.dart';

import 'catalog_header_info.dart';

class CatalogHeader extends ConsumerWidget {
  final String selectedForm;
  final ValueChanged<String> onFormChanged;

  const CatalogHeader({
    super.key,
    required this.selectedForm,
    required this.onFormChanged,
  });

  static const double _bp = 820;

  static double _responsiveGap(double w) {
    const minG = 8.0;
    const maxG = 20.0;
    const start = 480.0;
    const end = 1440.0;
    final t = ((w - start) / (end - start)).clamp(0.0, 1.0);
    return lerpDouble(minG, maxG, t)!;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < _bp;
    final gap = _responsiveGap(width);

    final logoUrl = ref.watch(tenantLogoUrlProvider);

    final Widget logo = (logoUrl == null)
        ? const SizedBox(height: 120)
        : Image.network(logoUrl, height: 120, fit: BoxFit.contain);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.35),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 110, child: Center(child: logo)),
                  const SizedBox(height: 10),
                  CatalogHeaderInfo(
                    centered: true, // 👈 center button + info
                    onLogin: () async {
                      await requireAuth(context, ref);
                    },
                  ),
                  SizedBox(height: gap),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 16),
                  SizedBox(width: 240, height: 120, child: Center(child: logo)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: CatalogHeaderInfo(
                        onLogin: () async {
                          await requireAuth(context, ref);
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
