// lib/shared/providers/users/user_profile_stream_provider.dart

import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/users/models/user_profile_model.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';

final userProfileStreamProvider = StreamProvider<List<UserProfile>>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  final collection = db.collection('tenants/$tenantId/user_profiles');

  return collection.snapshots().map((snapshot) {
    return snapshot.docs
        .where((doc) => doc.exists && doc.data().isNotEmpty)
        .map((doc) => UserProfile.fromMap(doc.id, doc.data()))
        .toList();
  });
});
