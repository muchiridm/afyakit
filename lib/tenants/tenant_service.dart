// lib/tenants/tenant_service.dart
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/tenants/tenant_model.dart';

class TenantService {
  TenantService(this.db);
  final FirebaseFirestore db;

  String slugify(String input) {
    final s = input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isNotEmpty ? s : 'tenant';
  }

  // lib/tenants/tenant_service.dart
  Stream<List<Tenant>> streamTenants() {
    return db
        .collection('tenants')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Tenant.fromDoc).toList());
  }

  /// Upsert a tenant doc whose id == slug.
  Future<String> createTenant({
    required String displayName,
    String? slug,
    String primaryColor = '#1565C0',
    String? logoPath,
    Map<String, dynamic> flags = const {},
  }) async {
    final desired = (slug?.trim().isNotEmpty == true)
        ? slug!.trim().toLowerCase()
        : slugify(displayName);

    final docRef = db.collection('tenants').doc(desired);
    return db.runTransaction<String>((tx) async {
      final exists = await tx.get(docRef);
      if (exists.exists) throw StateError('slug-taken');

      tx.set(docRef, {
        'slug': desired,
        'displayName': displayName,
        'primaryColor': primaryColor,
        if (logoPath != null) 'logoPath': logoPath,
        'flags': flags,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return desired;
    });
  }

  Future<void> setStatusBySlug(String slug, String status) async {
    await db.doc('tenants/$slug').set({
      'status': status,
    }, SetOptions(merge: true));
  }

  Future<void> updateTenant({
    required String slug, // doc id
    String? displayName,
    String? primaryColor,
    String? logoPath,
    Map<String, dynamic>? flags, // full replace for now
  }) async {
    final payload = <String, dynamic>{};
    if (displayName != null) payload['displayName'] = displayName;
    if (primaryColor != null) payload['primaryColor'] = primaryColor;
    if (logoPath != null) payload['logoPath'] = logoPath;
    if (flags != null) payload['flags'] = flags;

    if (payload.isEmpty) return;

    await db.doc('tenants/$slug').set(payload, SetOptions(merge: true));
  }
}
