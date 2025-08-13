//lib/shared/providers/streams/app_users_stream_provider.dart

import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/users/models/auth_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/providers/tenant_id_provider.dart';

final authUserStreamProvider = StreamProvider<List<AuthUser>>((ref) {
  final tenantId = ref.watch(tenantIdProvider);

  final query = db
      .collection('tenants/$tenantId/auth_users')
      .orderBy('email'); // ✅ safer than displayName

  return query.snapshots().map((snapshot) {
    return snapshot.docs
        .where((doc) => doc.exists && doc.data().isNotEmpty)
        .map((doc) => AuthUser.fromMap(doc.id, doc.data()))
        .toList();
  });
});
