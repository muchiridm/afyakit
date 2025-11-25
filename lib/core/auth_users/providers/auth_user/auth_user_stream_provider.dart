// lib/core/auth_users/providers/auth_user_stream_provider.dart
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';

List<AuthUser> _sortedByEmail(Iterable<AuthUser> users) {
  final out = users.toList()
    ..sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
  return out;
}

final authUserStreamProvider = StreamProvider.autoDispose<List<AuthUser>>((
  ref,
) {
  final tenantId = ref.watch(tenantSlugProvider);
  final query = db.collection('tenants/$tenantId/auth_users').orderBy('email');

  return query.snapshots().map((snapshot) {
    final mapped = snapshot.docs.where((d) => d.exists).map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['tenantId'] ??= tenantId; // tolerate legacy
      try {
        return AuthUser.fromMap(doc.id, data);
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Skipping ${doc.id}: $e');
        return null;
      }
    }).whereType<AuthUser>();

    return _sortedByEmail(mapped);
  });
});
