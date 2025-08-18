// lib/hq/tenants/tenant_controller.dart
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/users/providers/user_engine_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/hq/tenants/tenant_service.dart';

final tenantControllerProvider = Provider<TenantController>((ref) {
  final svc = ref.watch(tenantServiceProvider);
  return TenantController(ref, svc);
});

class TenantController {
  TenantController(this.ref, this._svc);
  final Ref ref;
  final TenantService _svc;

  /// Create a tenant and (optionally) set an owner + seed admins.
  /// If only `ownerEmail` is provided (no ownerUid), we send an invite to that email.
  Future<void> createTenant({
    required BuildContext context,
    required String displayName,
    String? slug,
    String primaryColor = '#1565C0',
    String? logoPath,
    Map<String, dynamic> flags = const {},
    String? ownerUid,
    String? ownerEmail,
    List<String> seedAdminUids = const <String>[],
  }) async {
    if (displayName.trim().isEmpty) {
      _toast(context, 'Display name is required');
      return;
    }
    try {
      final id = await _svc.createTenant(
        displayName: displayName.trim(),
        slug: slug?.trim().isEmpty == true ? null : slug?.trim(),
        primaryColor: primaryColor.trim().isEmpty
            ? '#1565C0'
            : primaryColor.trim(),
        logoPath: (logoPath?.trim().isEmpty ?? true) ? null : logoPath!.trim(),
        flags: flags,
        ownerUid: (ownerUid?.trim().isEmpty ?? true) ? null : ownerUid!.trim(),
        ownerEmail: (ownerEmail?.trim().isEmpty ?? true)
            ? null
            : ownerEmail!.trim(),
        seedAdminUids: seedAdminUids
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList(),
      );

      // If we only got ownerEmail (no uid yet), invite them now so they can activate.
      if ((ownerUid == null || ownerUid.trim().isEmpty) &&
          (ownerEmail != null && ownerEmail.trim().isNotEmpty)) {
        final engine = await ref.read(authUserEngineProvider(id).future);
        final res = await engine.invite(email: ownerEmail.trim());
        res.when(
          ok: (_) => _toast(context, 'Owner invite sent to $ownerEmail'),
          err: (e) => _toast(context, 'Owner invite failed: ${e.message}'),
        );
      }

      _toast(context, 'Tenant created ✓ (id: $id)');
    } on StateError catch (e) {
      _toast(
        context,
        e.message == 'slug-taken'
            ? 'Slug is already taken'
            : 'Failed: ${e.message}',
      );
      rethrow;
    } catch (e) {
      _toast(context, 'Error: $e');
      rethrow;
    }
  }

  /// Toggle tenant status between 'active' and 'suspended'.
  Future<void> toggleStatusBySlug(
    BuildContext context,
    String slug,
    String currentStatus,
  ) async {
    final next = currentStatus == 'active' ? 'suspended' : 'active';
    try {
      await _svc.setStatusBySlug(slug, next);
      _toast(context, 'Tenant $slug → $next');
    } catch (e) {
      _toast(context, 'Failed to update status: $e');
      rethrow;
    }
  }

  /// Edit basic tenant fields.
  Future<void> editTenant({
    required BuildContext context,
    required String slug,
    String? displayName,
    String? primaryColor,
    String? logoPath,
    Map<String, dynamic>? flags,
  }) async {
    try {
      String? pc = primaryColor;
      if (pc != null && pc.trim().isNotEmpty) {
        pc = _normalizeHex(pc);
      }
      await _svc.updateTenant(
        slug: slug,
        displayName: (displayName?.trim().isEmpty ?? true)
            ? null
            : displayName!.trim(),
        primaryColor: (pc?.trim().isEmpty ?? true) ? null : pc!.trim(),
        logoPath: (logoPath?.trim().isEmpty ?? true) ? null : logoPath!.trim(),
        flags: flags,
      );
      _toast(context, 'Updated "$slug"');
    } catch (e) {
      _toast(context, 'Failed to update: $e');
      rethrow;
    }
  }

  /// Transfer ownership to a new user (ensures membership as admin).
  Future<void> transferOwner(
    BuildContext context, {
    required String slug,
    required String newOwnerUid,
  }) async {
    try {
      final target = newOwnerUid.trim();
      if (target.isEmpty) {
        _toast(context, 'New owner UID is required');
        return;
      }
      await _svc.transferOwnership(
        slug: slug,
        newOwnerUid: target,
        ensureMember: true,
      );
      _toast(context, 'Ownership transferred');
    } catch (e) {
      _toast(context, 'Failed to transfer: $e');
      rethrow;
    }
  }

  /// Add or upgrade a tenant-scoped admin/manager (UID path).
  Future<void> addAdmin(
    BuildContext context, {
    required String slug,
    required String uid,
    String role = 'admin', // 'admin' | 'manager'
    String? email,
    String? displayName,
  }) async {
    try {
      final target = uid.trim();
      if (target.isEmpty) {
        _toast(context, 'UID is required');
        return;
      }
      await _svc.addAdmin(
        slug: slug,
        uid: target,
        role: role,
        email: (email?.trim().isEmpty ?? true) ? null : email!.trim(),
        displayName: (displayName?.trim().isEmpty ?? true)
            ? null
            : displayName!.trim(),
      );
      _toast(context, 'Admin added');
    } catch (e) {
      _toast(context, 'Failed to add admin: $e');
      rethrow;
    }
  }

  /// Remove (soft by default) a tenant-scoped admin/manager.
  Future<void> removeAdmin(
    BuildContext context, {
    required String slug,
    required String uid,
    bool softDelete = true,
  }) async {
    try {
      final target = uid.trim();
      if (target.isEmpty) {
        _toast(context, 'UID is required');
        return;
      }
      await _svc.removeAdmin(slug: slug, uid: target, softDelete: softDelete);
      _toast(context, 'Admin removed');
    } catch (e) {
      _toast(context, 'Failed to remove admin: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // NEW: Invite flows (FE → backend via ApiClient)
  // ─────────────────────────────────────────────────────────────

  /// Invite a tenant admin by **email** with an assigned role.
  /// After activation, they’ll sign in with that role in the tenant.
  Future<void> inviteAdminByEmail(
    BuildContext context, {
    required String slug,
    required String email,
    String role = 'admin', // 'admin' | 'manager'
    bool forceResend = false,
  }) async {
    final cleaned = email.trim();
    if (cleaned.isEmpty) {
      _toast(context, 'Email is required');
      return;
    }

    // basic guard
    final normalizedRole = (role == 'manager') ? 'manager' : 'admin';

    try {
      final engine = await ref.read(authUserEngineProvider(slug).future);

      // Engine supports role on invite (controller is ready).
      final res = await engine.invite(
        email: cleaned,
        role: normalizedRole, // ← assign role here
        forceResend: forceResend,
      );

      res.when(
        ok: (_) =>
            _toast(context, 'Invite sent to $cleaned as $normalizedRole'),
        err: (e) => _toast(context, 'Invite failed: ${e.message}'),
      );
    } catch (e) {
      _toast(context, 'Invite failed: $e');
      rethrow;
    }
  }

  // ── internals ─────────────────────────────────────────────

  String _normalizeHex(String input) {
    final s = input.trim().toUpperCase();
    return s.startsWith('#') ? s : '#$s';
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
