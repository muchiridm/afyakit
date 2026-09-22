import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_profile_provider.dart';
import 'package:afyakit/core/branding/services/branding_storage.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

/// Primary logo for the currently booted tenant/app.
///
/// public/{tenantId}/{appId}/branding/logos/logo-primary.png
final appPrimaryLogoUrlProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final profile = await ref.watch(appProfileProvider.future);
  final appId = profile.id;

  final path = brandingLogoPath(
    tenantId: tenantId,
    appId: appId,
    type: BrandingLogoType.primary,
  );

  if (kDebugMode) {
    debugPrint('🖼️ [app-logo] Looking up: $path');
  }

  try {
    final url = await ref
        .read(brandingStorageServiceProvider)
        .getLogoDownloadUrl(
          tenantId: tenantId,
          appId: appId,
          type: BrandingLogoType.primary,
        );

    if (kDebugMode) {
      debugPrint(
        url == null
            ? '⚠️ [app-logo] Primary logo not found: $path'
            : '✅ [app-logo] Primary logo URL resolved: $path',
      );
    }

    return url;
  } catch (error) {
    if (kDebugMode) {
      debugPrint(
        '❌ [app-logo] Primary logo lookup failed: '
        '$path — $error',
      );
    }

    rethrow;
  }
});

/// Secondary logo for the currently booted tenant/app.
///
/// public/{tenantId}/{appId}/branding/logos/logo-secondary.png
final appSecondaryLogoUrlProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final profile = await ref.watch(appProfileProvider.future);
  final appId = profile.id;

  final path = brandingLogoPath(
    tenantId: tenantId,
    appId: appId,
    type: BrandingLogoType.secondary,
  );

  if (kDebugMode) {
    debugPrint('🖼️ [app-logo] Looking up: $path');
  }

  try {
    final url = await ref
        .read(brandingStorageServiceProvider)
        .getLogoDownloadUrl(
          tenantId: tenantId,
          appId: appId,
          type: BrandingLogoType.secondary,
        );

    if (kDebugMode) {
      debugPrint(
        url == null
            ? '⚠️ [app-logo] Secondary logo not found: $path'
            : '✅ [app-logo] Secondary logo URL resolved: $path',
      );
    }

    return url;
  } catch (error) {
    if (kDebugMode) {
      debugPrint(
        '❌ [app-logo] Secondary logo lookup failed: '
        '$path — $error',
      );
    }

    rethrow;
  }
});
