// lib/shared/providers/streams/app_users_stream_provider.dart
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';

final authUserStreamProvider = StreamProvider.autoDispose<List<AuthUser>>((
  ref,
) {
  final tenantId = ref.watch(tenantIdProvider);

  final query = db.collection('tenants/$tenantId/auth_users').orderBy('email');

  return query.snapshots().map((snapshot) {
    final out = <AuthUser>[];
    for (final doc in snapshot.docs) {
      if (!doc.exists) continue;
      final raw = doc.data();
      if (raw.isEmpty) continue;

      // Be tolerant: some legacy docs may miss tenantId
      final data = Map<String, dynamic>.from(raw);
      data['tenantId'] ??= tenantId;

      try {
        out.add(AuthUser.fromMap(doc.id, data));
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Skipping ${doc.id}: $e');
      }
    }
    out.sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
    return out;
  });
});
