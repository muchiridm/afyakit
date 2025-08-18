// lib/hq/tenants/tenant_controller.dart
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/users/user_manager/providers/user_engine_providers.dart'; // for invites on a target tenant
import 'package:afyakit/tenants/services/tenant_service.dart';

final tenantControllerProvider = Provider<TenantController>((ref) {
  return TenantController(ref); // ⬅️ no direct service passed
});

class TenantController {
  TenantController(this.ref);
  final Ref ref;

  Future<TenantService> _svc() => ref.read(tenantServiceProvider.future);

  // ─────────────────────────────────────────────────────────────
  // Create tenant
  // ─────────────────────────────────────────────────────────────
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
      final svc = await _svc();
      final id = await svc.createTenant(
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

      // If only ownerEmail was provided, send an invite on the NEW tenant.
      if ((ownerUid == null || ownerUid.trim().isEmpty) &&
          (ownerEmail != null && ownerEmail.trim().isNotEmpty)) {
        final engine = await ref.read(userManagerEngineProvider(id).future);
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

  // ─────────────────────────────────────────────────────────────
  // Status toggle
  // ─────────────────────────────────────────────────────────────
  Future<void> toggleStatusBySlug(
    BuildContext context,
    String slug,
    String currentStatus,
  ) async {
    final next = currentStatus == 'active' ? 'suspended' : 'active';
    try {
      final svc = await _svc();
      await svc.setStatusBySlug(slug, next);
      _toast(context, 'Tenant $slug → $next');
    } catch (e) {
      _toast(context, 'Failed to update status: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Edit tenant
  // ─────────────────────────────────────────────────────────────
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
      final svc = await _svc();
      await svc.updateTenant(
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

  // ─────────────────────────────────────────────────────────────
  // Owner / Admin hooks used by the UI
  // ─────────────────────────────────────────────────────────────
  Future<void> transferOwner(
    BuildContext context, {
    required String slug,
    required String newOwnerUid,
  }) async {
    if (newOwnerUid.trim().isEmpty) {
      _toast(context, 'Owner UID is required');
      return;
    }
    try {
      final svc = await _svc();
      await svc.transferOwnership(slug: slug, newOwnerUid: newOwnerUid.trim());
      _toast(context, 'Ownership transferred to $newOwnerUid');
    } catch (e) {
      _toast(context, 'Failed to transfer ownership: $e');
      rethrow;
    }
  }

  Future<void> inviteAdminByEmail(
    BuildContext context, {
    required String slug,
    required String email,
    String role = 'admin',
    bool forceResend = false,
  }) async {
    final norm = email.trim();
    if (norm.isEmpty) {
      _toast(context, 'Email is required');
      return;
    }
    try {
      final engine = await ref.read(userManagerEngineProvider(slug).future);
      final res = await engine.invite(
        email: norm,
        role: role,
        forceResend: forceResend,
      );
      res.when(
        ok: (_) => _toast(context, 'Invite sent to $norm ($role)'),
        err: (e) => _toast(context, 'Invite failed: ${e.message}'),
      );
    } catch (e) {
      _toast(context, 'Invite failed: $e');
      rethrow;
    }
  }

  Future<void> addAdminByUid(
    BuildContext context, {
    required String slug,
    required String uid,
    String role = 'admin',
  }) async {
    try {
      final svc = await _svc();
      await svc.addAdmin(slug: slug, uid: uid.trim(), role: role);
      _toast(context, 'Admin added: $uid ($role)');
    } catch (e) {
      _toast(context, 'Failed to add admin: $e');
      rethrow;
    }
  }

  Future<void> removeAdmin(
    BuildContext context, {
    required String slug,
    required String uid,
    bool softDelete = true,
  }) async {
    try {
      final svc = await _svc();
      await svc.removeAdmin(slug: slug, uid: uid, softDelete: softDelete);
      _toast(context, 'Admin removed');
    } catch (e) {
      _toast(context, 'Failed to remove admin: $e');
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
