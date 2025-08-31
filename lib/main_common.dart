import 'package:afyakit/hq/core/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

import 'package:afyakit/app/afyakit_app.dart';
import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/hq/core/tenants/services/tenant_resolver.dart';
import 'package:afyakit/hq/core/tenants/services/tenant_config_loader.dart';

Future<void> bootstrapAndRun({required String defaultTenantSlug}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // invite flow parse
  final uri = Uri.base;
  final segs = uri.pathSegments;
  final uid = uri.queryParameters['uid'];
  final isInviteFlow =
      segs.length >= 2 &&
      segs[0] == 'invite' &&
      segs[1] == 'accept' &&
      uid != null;

  // resolve + load
  final slug = await resolveTenantSlugAsync(defaultSlug: defaultTenantSlug);
  debugPrint('🏢 Using tenant: $slug');

  final loader = TenantConfigLoader(FirebaseFirestore.instance);
  final cfg = await loader.load(slug);

  runApp(
    ProviderScope(
      overrides: [
        tenantIdProvider.overrideWithValue(slug),
        tenantConfigProvider.overrideWithValue(cfg),
      ],
      child: AfyaKitApp(
        isInviteFlow: isInviteFlow,
        inviteParams: isInviteFlow
            ? <String, String>{'tenant': slug, 'uid': uid}
            : null,
      ),
    ),
  );
}
