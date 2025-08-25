import 'package:afyakit/features/tenants/dialogs/add_admin_dialog.dart';
import 'package:afyakit/features/tenants/dialogs/confirm_dialog.dart';
import 'package:afyakit/features/tenants/dialogs/edit_tenant_dialog.dart';
import 'package:afyakit/shared/types/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/tenants/services/tenant_service.dart';
import 'package:afyakit/features/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/tenants/providers/tenant_user_providers.dart';
import 'package:afyakit/features/auth_users/providers/user_engine_providers.dart';

// Dumb-UI friendly controller
final tenantControllerProvider = Provider<TenantController>((ref) {
  return TenantController(ref);
});

class TenantController {
  TenantController(this.ref);
  final Ref ref;

  Future<TenantService> _svc() => ref.read(tenantServiceProvider.future);

  // ─────────────────────────────────────────────────────────────
  // Public helpers: invalidate caches so lists refresh immediately
  // ─────────────────────────────────────────────────────────────
  void refreshTenant(String slug) {
    ref.invalidate(tenantStreamBySlugProvider(slug));
    ref.invalidate(tenantAdminsStreamProvider(slug));
  }

  void refreshAllTenants() {
    ref.invalidate(tenantsStreamProvider);
  }

  // ─────────────────────────────────────────────────────────────
  // Create tenant (CRUD only)
  // ─────────────────────────────────────────────────────────────
  Future<void> createTenant({
    required BuildContext context,
    required String displayName,
    String? slug,
    String primaryColor = '#1565C0',
    String? logoPath,
    Map<String, dynamic> flags = const {},
  }) async {
    if (displayName.trim().isEmpty) {
      _toast(context, 'Display name is required');
      return;
    }
    try {
      final svc = await _svc();
      final id = await svc.createTenant(
        displayName: displayName.trim(),
        slug: slug?.trim().isNotEmpty == true ? slug!.trim() : null,
        primaryColor: primaryColor.trim().isNotEmpty
            ? primaryColor.trim()
            : '#1565C0',
        logoPath: (logoPath?.trim().isNotEmpty ?? false)
            ? logoPath!.trim()
            : null,
        flags: flags,
      );
      _toast(context, 'Tenant created ✓ (id: $id)');
      refreshAllTenants();
    } catch (e) {
      _toast(context, 'Error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Toggle status (active <-> suspended)
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
      refreshTenant(slug);
      refreshAllTenants();
    } catch (e) {
      _toast(context, 'Failed to update status: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Edit tenant (CRUD)
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
        displayName: (displayName?.trim().isNotEmpty ?? false)
            ? displayName!.trim()
            : null,
        primaryColor: (pc?.trim().isNotEmpty ?? false) ? pc!.trim() : null,
        logoPath: (logoPath?.trim().isNotEmpty ?? false)
            ? logoPath!.trim()
            : null,
        flags: flags,
      );
      _toast(context, 'Updated "$slug"');
      refreshTenant(slug);
      refreshAllTenants();
    } catch (e) {
      _toast(context, 'Failed to update: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Convenience: Edit with dialog (UI stays dumb)
  // ─────────────────────────────────────────────────────────────
  Future<void> editTenantWithDialog(
    BuildContext context, {
    required String slug,
    required String initialDisplayName,
    required String initialPrimaryColor,
    required String? initialLogoPath,
  }) async {
    // Lazy import to keep controller central (still UI-owned dialog)
    // ignore: avoid_dynamic_calls
    final payload = await showDialog<dynamic>(
      context: context,
      builder: (_) => EditTenantDialog(
        initialDisplayName: initialDisplayName,
        initialPrimaryColor: initialPrimaryColor,
        initialLogoPath: initialLogoPath,
      ),
    );
    if (payload != null) {
      await editTenant(
        context: context,
        slug: slug,
        displayName: payload.displayName,
        primaryColor: payload.primaryColor,
        logoPath: payload.logoPath,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Delete tenant (CRUD)
  // ─────────────────────────────────────────────────────────────
  Future<void> deleteTenant({
    required BuildContext context,
    required String slug,
    bool hard = false,
  }) async {
    try {
      final svc = await _svc();
      await svc.deleteTenant(slug, hard: hard);
      _toast(context, 'Tenant deleted: $slug');
      refreshAllTenants();
    } catch (e) {
      _toast(context, 'Failed to delete: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Admin/User operations — via UserManagerEngine (HQ)
  // Keep UI fully dumb: controller shows dialogs, calls HQ, invalidates streams
  // ─────────────────────────────────────────────────────────────
  Future<void> addAdminWithDialog(
    BuildContext context, {
    required String slug,
  }) async {
    final result = await showDialog<AddAdminPayload>(
      context: context,
      builder: (_) => AddAdminDialog(tenantSlug: slug),
    );
    if (result == null) return;

    try {
      final engine = await ref.read(userManagerEngineProvider(slug).future);
      final r = await engine.hqInviteUserForTenant(
        targetTenantId: slug,
        email: result.email,
        role: result.role,
        forceResend: result.forceResend,
      );
      r.when(
        ok: (_) {
          _toast(context, 'Invite sent to ${result.email} (${result.role})');
          refreshTenant(slug); // makes the admins list update immediately
        },
        err: (e) => _toast(context, 'Invite failed: ${e.message}'),
      );
    } catch (e) {
      _toast(context, 'Invite failed: $e');
      rethrow;
    }
    refreshTenant(slug);
  }

  Future<void> removeAdminWithConfirm(
    BuildContext context, {
    required String slug,
    required String uid,
    String? label,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmDialog(
        title: 'Remove admin?',
        message: 'This will remove admin access for this user.',
        confirmLabel: 'Remove',
      ),
    );
    if (ok != true) return;

    try {
      final engine = await ref.read(userManagerEngineProvider(slug).future);
      final res = await engine.hqDeleteUserFromTenant(
        targetTenantId: slug,
        uid: uid,
      );
      switch (res) {
        case Ok<void>():
          _toast(context, 'Admin removed${label != null ? ' ($label)' : ''}');
          refreshTenant(slug);
        case Err<void>(:final error):
          _toast(context, 'HQ delete failed: ${error.message}');
      }
    } catch (e) {
      _toast(context, 'HQ delete failed: $e');
      rethrow;
    }
  }

  // Optional direct invite (not used by the above dialog flow)
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
      final res = await engine.hqInviteUserForTenant(
        targetTenantId: slug,
        email: norm,
        role: role,
        forceResend: forceResend,
      );
      res.when(
        ok: (_) {
          _toast(context, 'Invite sent to $norm ($role)');
          refreshTenant(slug);
        },
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
