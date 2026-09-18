// lib/core/domains/providers/domain_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/domains/models/domain_binding.dart';
import 'package:afyakit/core/domains/services/app_domain_service.dart';

typedef AppDomainScope = ({String tenantId, String appId});

/// Fetch-once list of domains owned by an app.
///
/// Refresh with:
/// ref.invalidate(
///   domainProvider((
///     tenantId: tenantId,
///     appId: appId,
///   )),
/// );
final domainProvider = FutureProvider.autoDispose
    .family<List<DomainBinding>, AppDomainScope>((ref, scope) async {
      final service = await ref.watch(appDomainServiceProvider.future);

      return service.listAppDomains(
        scope.tenantId.trim().toLowerCase(),
        scope.appId.trim().toLowerCase(),
      );
    });
