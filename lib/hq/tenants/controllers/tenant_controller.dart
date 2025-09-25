import 'package:afyakit/core/auth_users/extensions/user_role_x.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/hq/base/hq_controller.dart';
import 'package:afyakit/hq/tenants/dialogs/configure_tenant_dialog.dart';
import 'package:afyakit/hq/tenants/dialogs/create_tenant_dialog.dart';
import 'package:afyakit/hq/tenants/models/tenant_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/hq/tenants/dialogs/add_admin_dialog.dart';
import 'package:afyakit/hq/tenants/dialogs/confirm_dialog.dart';
import 'package:afyakit/hq/tenants/dialogs/edit_tenant_dialog.dart';
import 'package:afyakit/hq/tenants/models/tenant_payloads.dart';
import 'package:afyakit/hq/tenants/extensions/tenant_status_x.dart';

import 'package:afyakit/hq/users/super_admins/super_admins_controller.dart';

import 'package:afyakit/hq/tenants/services/tenant_service.dart';
import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';

final tenantControllerProvider = Provider<TenantController>((ref) {
  return TenantController(ref);
});

class TenantController {
  TenantController(this.ref);
  final Ref ref;

  Future<TenantService> _svc() => ref.read(tenantServiceProvider.future);

  // ─────────────────────────────────────────────────────────────
  // Cache invalidation helpers
  // ─────────────────────────────────────────────────────────────
  void refreshTenant(String slug) {
    ref.invalidate(tenantStreamBySlugProvider(slug));
    ref.invalidate(tenantAdminsStreamProvider(slug));
  }

  void refreshAllTenants() {
    ref.invalidate(tenantsStreamProvider);
  }

  // ─────────────────────────────────────────────────────────────
  // Create tenant (CRUD)
  // ─────────────────────────────────────────────────────────────
  Future<void> createTenant({
    required BuildContext context,
    required String displayName,
    String? slug,
    String primaryColor = '#1565C0',
    String? logoPath,
    Map<String, dynamic> flags = const {},
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      _toast(context, 'Display name is required');
      return;
    }

    try {
      final svc = await _svc();
      final createdSlug = await svc.createTenant(
        displayName: name,
        slug: (slug?.trim().isNotEmpty ?? false) ? slug!.trim() : null,
        primaryColor: primaryColor.trim().isNotEmpty
            ? _normalizeHex(primaryColor)
            : '#1565C0',
        logoPath: (logoPath?.trim().isNotEmpty ?? false)
            ? logoPath!.trim()
            : null,
        flags: flags,
      );
      _toast(context, 'Tenant created ✓ (id: $createdSlug)');
      refreshAllTenants();
    } catch (e) {
      _toast(context, 'Error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Status: toggle / set explicit (uses enum)
  // ─────────────────────────────────────────────────────────────
  Future<void> toggleStatusBySlug(
    BuildContext context,
    String slug,
    TenantStatus current,
  ) async {
    final next = current.isDeleted
        ? TenantStatus
              .active // restore from deleted
        : (current.isActive ? TenantStatus.suspended : TenantStatus.active);

    await setStatusBySlug(context, slug, next);
  }

  Future<void> setStatusBySlug(
    BuildContext context,
    String slug,
    TenantStatus next,
  ) async {
    try {
      final svc = await _svc();
      await svc.setStatusBySlug(slug, next); // enum -> service maps to wire
      final msg = switch (next) {
        TenantStatus.active => 'Tenant activated',
        TenantStatus.suspended => 'Tenant suspended',
        TenantStatus.deleted => 'Tenant deleted',
      };
      _toast(context, '$msg ($slug)');
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
      final normalizedPrimary = (primaryColor?.trim().isNotEmpty ?? false)
          ? _normalizeHex(primaryColor!)
          : null;

      final svc = await _svc();
      await svc.updateTenant(
        slug: slug,
        displayName: (displayName?.trim().isNotEmpty ?? false)
            ? displayName!.trim()
            : null,
        primaryColor: normalizedPrimary,
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

  /// UI convenience: open edit dialog then call [editTenant].
  Future<void> editTenantWithDialog(
    BuildContext context, {
    required String slug,
    required String initialDisplayName,
    required String initialPrimaryColor,
    required String? initialLogoPath,
  }) async {
    final payload = await showDialog<EditTenantPayload>(
      context: context,
      builder: (_) => EditTenantDialog(
        initialDisplayName: initialDisplayName,
        initialPrimaryColor: initialPrimaryColor,
        initialLogoPath: initialLogoPath,
      ),
    );
    if (payload == null) return;

    await editTenant(
      context: context,
      slug: slug,
      displayName: payload.displayName,
      primaryColor: payload.primaryColor,
      logoPath: payload.logoPath,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Delete tenant (soft by default; hard optional)
  // ─────────────────────────────────────────────────────────────
  Future<void> deleteTenant({
    required BuildContext context,
    required String slug,
    bool hard = false,
  }) async {
    try {
      final svc = await _svc();
      await svc.deleteTenant(slug, hard: hard);
      _toast(
        context,
        hard ? 'Tenant permanently deleted' : 'Tenant marked as deleted',
      );
      refreshAllTenants();
    } catch (e) {
      _toast(context, 'Failed to delete: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Admin/User ops — delegate to SuperAdminsController (HQ)
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

    final hq = ref.read(superAdminsControllerProvider.notifier);
    final invite = await hq.inviteUserForTenant(
      targetTenantId: slug,
      email: result.email,
      role: result.role,
      forceResend: result.forceResend,
    );

    if (invite != null) {
      refreshTenant(slug);
    }
  }

  Future<void> removeAdminWithConfirm(
    BuildContext context, {
    required String slug,
    required String uid,
    String? label,
  }) async {
    final ok = await _confirm(
      context,
      title: 'Remove admin?',
      message: 'This will remove admin access for this user.',
      confirmLabel: 'Remove',
    );
    if (ok != true) return;

    final hq = ref.read(superAdminsControllerProvider.notifier);
    await hq.deleteUserFromTenant(targetTenantId: slug, uid: uid, label: label);
    refreshTenant(slug);
  }

  /// Optional direct invite
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

    final hq = ref.read(superAdminsControllerProvider.notifier);
    final res = await hq.inviteUserForTenant(
      targetTenantId: slug,
      email: norm,
      role: role,
      forceResend: forceResend,
    );

    if (res != null) {
      refreshTenant(slug);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Transfer Owner (UI convenience)
  // ─────────────────────────────────────────────────────────────
  Future<void> transferOwner(
    BuildContext context, {
    required String slug,
    required String target, // email or uid
  }) async {
    final who = target.trim();
    if (who.isEmpty) {
      _toast(context, 'Email or UID is required');
      return;
    }

    try {
      final svc = await _svc();
      if (_looksLikeEmail(who)) {
        await svc.setOwnerByEmail(slug: slug, email: who);
      } else {
        await svc.setOwnerByUid(slug: slug, uid: who);
      }

      _toast(context, 'Owner transferred to $who');
      refreshTenant(slug);
      refreshAllTenants();
    } catch (e) {
      _toast(context, 'Failed to transfer owner: $e');
      rethrow;
    }
  }

  /// Remove (demote/remove) the current owner using email or uid.
  /// If both provided, email wins.
  Future<void> removeOwner(
    BuildContext context, {
    required String slug,
    String? email,
    String? uid,
    required bool hard, // false = demote to admin, true = remove membership
  }) async {
    final who = (email?.trim().isNotEmpty == true)
        ? email!.trim()
        : (uid?.trim().isNotEmpty == true ? uid!.trim() : '');

    if (who.isEmpty) {
      _toast(context, 'No owner set');
      return;
    }

    final verb = hard ? 'Remove owner from tenant' : 'Demote owner to admin';
    final ok = await _confirm(
      context,
      title: hard ? 'Remove owner?' : 'Demote owner?',
      message: hard
          ? 'This will remove the current owner from this tenant.'
          : 'This will change the owner’s role to admin.',
      confirmLabel: hard ? 'Remove' : 'Demote',
    );
    if (ok != true) return;

    try {
      final svc = await _svc();
      if (email?.trim().isNotEmpty == true) {
        await svc.removeOwnerByEmail(
          slug: slug,
          email: email!.trim(),
          hard: hard,
        );
      } else {
        await svc.removeOwnerByUid(slug: slug, uid: uid!, hard: hard);
      }
      _toast(context, '$verb ✓');
      refreshTenant(slug);
      refreshAllTenants();
    } catch (e) {
      _toast(context, 'Failed: $e');
      rethrow;
    }
  }

  /// Open the full config dialog, gather changes, and apply.
  Future<void> configureTenantWithDialog(
    BuildContext context, {
    required Tenant tenant,
  }) async {
    final svc = await _svc();

    // Preload current domains for the Domains tab
    final domains = await svc.listTenantDomains(tenant.slug);

    final result = await showDialog<ConfigureTenantResult>(
      context: context,
      builder: (_) => ConfigureTenantDialog(tenant: tenant, domains: domains),
    );

    if (result == null || result.isNoop) return;

    try {
      // 1) PATCH /tenants/:slug (only if any field provided)
      if (result.edit != null) {
        await editTenant(
          context: context,
          slug: tenant.slug,
          displayName: result.edit!.displayName,
          primaryColor: result.edit!.primaryColor,
          logoPath: result.edit!.logoPath,
          flags: result.edit!.flags,
        );
      }

      // 2) POST /tenants/:slug/status
      if (result.setStatus != null && result.setStatus != tenant.status) {
        await setStatusBySlug(context, tenant.slug, result.setStatus!);
      }

      // 3) POST /tenants/:slug/owner
      final newOwner = result.transferOwnerTarget?.trim();
      if (newOwner != null && newOwner.isNotEmpty) {
        await transferOwner(context, slug: tenant.slug, target: newOwner);
      }

      // 4) Domain mutations (HQ superadmin endpoints)
      if (result.domainOps.isNotEmpty) {
        await _applyDomainOps(svc, tenant.slug, result.domainOps);
        _toast(context, 'Domain changes applied');
      }

      // Final refresh
      refreshTenant(tenant.slug);
      refreshAllTenants();
    } catch (e) {
      _toast(context, 'Failed to apply configuration: $e');
      rethrow;
    }
  }

  Future<void> _applyDomainOps(
    TenantService svc,
    String slug,
    List<DomainOp> ops,
  ) async {
    for (final op in ops) {
      switch (op.action) {
        case DomainAction.add:
          // Optionally read back dnsToken to show in UI if you want
          await svc.addTenantDomain(slug, op.domain);
          break;
        case DomainAction.verify:
          await svc.verifyTenantDomain(slug, op.domain);
          break;
        case DomainAction.makePrimary:
          await svc.setPrimaryTenantDomain(slug, op.domain);
          break;
        case DomainAction.remove:
          await svc.removeTenantDomain(slug, op.domain);
          break;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Internals
  // ─────────────────────────────────────────────────────────────
  bool _looksLikeEmail(String v) {
    final s = v.trim();
    if (!s.contains('@')) return false;
    final parts = s.split('@');
    if (parts.length != 2) return false;
    if (parts[0].isEmpty || parts[1].isEmpty) return false;
    return parts[1].contains('.');
  }

  String _normalizeHex(String input) {
    final s = input.trim().toUpperCase();
    return s.startsWith('#') ? s : '#$s';
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

extension TenantFlows on TenantController {
  /// Full create flow: open dialog, validate, call API, manage busy/snack, refresh.
  Future<void> createTenantViaDialog(BuildContext context) async {
    final payload = await showDialog<CreateTenantPayload>(
      context: context,
      builder: (_) => const CreateTenantDialog(),
    );
    if (payload == null) return;

    final hq = ref.read(hqControllerProvider.notifier);
    await hq.withBusy(
      context,
      () => createTenant(
        context: context,
        displayName: payload.displayName,
        slug: payload.slug,
        primaryColor: payload.primaryColor,
        logoPath: payload.logoPath,
        flags: payload.flags,
      ),
      success: 'Tenant created',
    );
  }

  /// Fetch + filter admins for a tenant (owner/admin/manager), already sorted.
  Future<List<AuthUser>> listAdminsForTenant(String slug) async {
    final hq = ref.read(superAdminsControllerProvider.notifier);
    final all = await hq.listUsersForTenant(slug, silent: true);
    final admins =
        all.where((u) {
          switch (u.role) {
            case UserRole.owner:
            case UserRole.admin:
            case UserRole.manager:
              return true;
            case UserRole.staff:
            case UserRole.client:
              return false;
          }
        }).toList()..sort(
          (a, b) => (a.email.isNotEmpty ? a.email : (a.phoneNumber ?? a.uid))
              .toLowerCase()
              .compareTo(
                (b.email.isNotEmpty ? b.email : (b.phoneNumber ?? b.uid))
                    .toLowerCase(),
              ),
        );
    return admins;
  }
}
