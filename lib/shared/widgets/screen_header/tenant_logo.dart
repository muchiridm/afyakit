// lib/shared/widgets/screen_header/tenant_logo.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';

class TenantLogo extends ConsumerWidget {
  final double? height;
  final double? width;
  const TenantLogo({super.key, this.height, this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(tenantConfigProvider);
    final tenantId = cfg.id;

    final double h = height ?? 54;

    String path;
    switch (tenantId) {
      case 'dawapap':
        path = 'branding/dawapap/logo_header.png'; // 👈 your cropped/header PNG
        break;
      case 'danabtmc':
        path = 'branding/danabtmc/logo_mark.png';
        break;
      default:
        path = 'branding/afyakit/logo_mark.png';
    }

    return Image.asset(
      path,
      height: h,
      width: width,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
    );
  }
}
