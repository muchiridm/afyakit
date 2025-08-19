// lib/hq/tenants/tenant_controller.dart
import 'package:afyakit/shared/types/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/tenants/services/tenant_service.dart';
import 'package:afyakit/tenants/providers/tenant_providers.dart';
import 'package:afyakit/users/user_manager/providers/user_engine_providers.dart';

final tenantControllerProvider = Provider<TenantController>((ref) {
  return TenantController(ref);
});

class TenantController {
  TenantController(this.ref);
  final Ref ref;

  Future<TenantService> _svc() => ref.read(tenantServiceProvider.future);

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
    // NOTE: ownership/admin invites are handled by User Manager,
    // not here. If you need to invite an owner after creation,
    // do it from the UI using userManagerEngineProvider(newSlug).
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
        primaryColor: primaryColor.trim().isNotEmpty
            ? primaryColor.trim()
            : '#1565C0',
        logoPath: (logoPath?.trim().isEmpty ?? true) ? null : logoPath!.trim(),
        flags: flags,
      );

      _toast(context, 'Tenant created ✓ (id: $id)');
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
  // Flags (compat helper)
  // ─────────────────────────────────────────────────────────────
  Future<void> setFlag({
    required BuildContext context,
    required String slug,
    required String key,
    required Object? value,
  }) async {
    try {
      final svc = await _svc();
      await svc.setFlag(slug, key, value);
      _toast(context, 'Flag "$key" updated');
    } catch (e) {
      _toast(context, 'Failed to set flag: $e');
      rethrow;
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
    } catch (e) {
      _toast(context, 'Failed to delete: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Admin/User operations → delegate to User Manager engine
  // (Keep these small wrappers only if your UI still calls them)
  // ─────────────────────────────────────────────────────────────

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

  // ── internals ─────────────────────────────────────────────
  String _normalizeHex(String input) {
    final s = input.trim().toUpperCase();
    return s.startsWith('#') ? s : '#$s';
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
