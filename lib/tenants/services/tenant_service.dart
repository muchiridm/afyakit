// lib/hq/tenants/services/tenant_service.dart

import 'package:afyakit/config/tenant_config.dart'; // TenantConfig + color utils
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/tenants/tenant_model.dart';

/// Service for managing tenants and tenant-scoped admins (auth_users).
/// - Ownership lives on the tenant doc: `ownerUid` (single source of truth).
/// - Admins live under: `tenants/{slug}/auth_users/{uid}` with {role, active}.
class TenantService {
  TenantService(this.db);
  final FirebaseFirestore db;

  // ─────────────────────────────────────────────
  // Utils
  // ─────────────────────────────────────────────

  /// Lowercase, strip non [a-z0-9 -], collapse spaces to '-', collapse dashes.
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

  DocumentReference<Map<String, dynamic>> _tenantRef(String slug) =>
      db.collection('tenants').doc(slug);

  DocumentReference<Map<String, dynamic>> _memberRef(String slug, String uid) =>
      _tenantRef(slug).collection('auth_users').doc(uid);

  // ─────────────────────────────────────────────
  // Reads (lists + config)
  // ─────────────────────────────────────────────

  Stream<List<Tenant>> streamTenants() {
    return db
        .collection('tenants')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Tenant.fromDoc).toList());
  }

  /// Load the **config** for a single tenant (server preferred, cache fallback).
  Future<TenantConfig> fetchConfig(String slug) async {
    final doc = await _tenantRef(
      slug,
    ).get(const GetOptions(source: Source.serverAndCache));
    if (!doc.exists || doc.data() == null) {
      throw StateError('Tenant config not found: $slug');
    }
    return TenantConfig.fromFirestore(doc.id, doc.data()!);
  }

  /// Live updates to tenant config (theme/feature flags can react at runtime).
  Stream<TenantConfig> watchConfig(String slug) {
    return _tenantRef(slug)
        .snapshots()
        .where((s) => s.exists && s.data() != null)
        .map((s) => TenantConfig.fromFirestore(s.id, s.data()!));
  }

  // ─────────────────────────────────────────────
  // Writes (create / status / updates)
  // ─────────────────────────────────────────────

  /// Create a tenant (doc id == slug), optionally setting an owner and seeding admins.
  ///
  /// - `ownerUid`: canonical owner; also ensured as a member (role 'admin').
  /// - `seedAdminUids`: any extra admins to create under auth_users.
  Future<String> createTenant({
    required String displayName,
    String? slug,
    String primaryColor = '#1565C0',
    String? logoPath,
    Map<String, dynamic> flags = const {},
    String? ownerUid, // NEW
    String? ownerEmail, // optional (display/convenience)
    List<String> seedAdminUids = const [], // NEW
  }) async {
    final desired = (slug?.trim().isNotEmpty == true)
        ? slug!.trim().toLowerCase()
        : slugify(displayName);

    final tenantRef = _tenantRef(desired);

    // de-dup + sanitize admin list
    final dedupSeed = <String>{for (final s in seedAdminUids) s.trim()}
      ..removeWhere((s) => s.isEmpty || s == ownerUid);

    await db.runTransaction<void>((tx) async {
      final exists = await tx.get(tenantRef);
      if (exists.exists) throw StateError('slug-taken');

      tx.set(tenantRef, {
        'slug': desired,
        'displayName': displayName,
        'primaryColor': primaryColor,
        if (logoPath != null) 'logoPath': logoPath,
        'flags': flags,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        if (ownerUid != null && ownerUid.isNotEmpty) 'ownerUid': ownerUid,
        if (ownerEmail != null && ownerEmail.isNotEmpty)
          'ownerEmail': ownerEmail,
      });

      // Owner as member (role 'admin'); ownership still comes from tenant.ownerUid.
      if (ownerUid != null && ownerUid.isNotEmpty) {
        tx.set(_memberRef(desired, ownerUid), {
          'uid': ownerUid,
          'role': 'admin',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Seed extra admins
      for (final uid in dedupSeed) {
        tx.set(_memberRef(desired, uid), {
          'uid': uid,
          'role': 'admin',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });

    return desired;
  }

  Future<void> setStatusBySlug(String slug, String status) async {
    await _tenantRef(slug).set({'status': status}, SetOptions(merge: true));
  }

  Future<void> updateTenant({
    required String slug,
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
    await _tenantRef(slug).set(payload, SetOptions(merge: true));
  }

  /// Patch a single flag without replacing the whole map.
  Future<void> setFlag(String slug, String key, Object? value) async {
    await _tenantRef(slug).set({'flags.$key': value}, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────
  // Ownership (canonical on tenant doc)
  // ─────────────────────────────────────────────

  /// Change the canonical owner. Optionally ensures the new owner is an active admin member.
  Future<void> transferOwnership({
    required String slug,
    required String newOwnerUid,
    bool ensureMember = true,
  }) async {
    final tenantRef = _tenantRef(slug);
    final newOwnerMemberRef = _memberRef(slug, newOwnerUid);

    await db.runTransaction<void>((tx) async {
      final tSnap = await tx.get(tenantRef);
      if (!tSnap.exists) throw StateError('tenant-not-found');

      if (ensureMember) {
        final mSnap = await tx.get(newOwnerMemberRef);
        final isActive = mSnap.exists && (mSnap.data()?['active'] == true);
        if (!isActive) {
          tx.set(newOwnerMemberRef, {
            'uid': newOwnerUid,
            'role': 'admin',
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      tx.update(tenantRef, {'ownerUid': newOwnerUid});
    });
  }

  // ─────────────────────────────────────────────
  // Tenant admins (tenant-scoped auth_users)
  // ─────────────────────────────────────────────

  /// Stream active admins/managers under a tenant.
  Stream<List<Map<String, dynamic>>> streamAdmins(String slug) {
    return _tenantRef(slug)
        .collection('auth_users')
        .where('active', isEqualTo: true)
        .where('role', whereIn: ['admin', 'manager'])
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// Add/upgrade an admin or manager in the tenant's auth_users.
  Future<void> addAdmin({
    required String slug,
    required String uid,
    String role = 'admin', // 'admin' | 'manager'
    String? email,
    String? displayName,
  }) async {
    final ref = _memberRef(slug, uid);
    await ref.set({
      'uid': uid,
      'role': role,
      'active': true,
      if (email != null && email.isNotEmpty) 'email': email,
      if (displayName != null && displayName.isNotEmpty)
        'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Soft-remove an admin (active=false) or hard-delete the membership.
  Future<void> removeAdmin({
    required String slug,
    required String uid,
    bool softDelete = true,
  }) async {
    final ref = _memberRef(slug, uid);
    if (softDelete) {
      await ref.set({'active': false}, SetOptions(merge: true));
    } else {
      await ref.delete();
    }
  }
}
