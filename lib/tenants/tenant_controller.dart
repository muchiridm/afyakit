import 'package:afyakit/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/tenants/tenant_service.dart';

final tenantControllerProvider = Provider<TenantController>((ref) {
  final svc = ref.watch(tenantServiceProvider);
  return TenantController(ref, svc);
});

class TenantController {
  TenantController(this.ref, this._svc);
  final Ref ref;
  final TenantService _svc;

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
      final id = await _svc.createTenant(
        displayName: displayName.trim(),
        slug: slug?.trim().isEmpty == true ? null : slug?.trim(),
        primaryColor: primaryColor.trim().isEmpty
            ? '#1565C0'
            : primaryColor.trim(),
        logoPath: logoPath,
        flags: flags,
      );
      _toast(context, 'Tenant created ✓ (id: $id)');
    } on StateError catch (e) {
      if (e.message == 'slug-taken') {
        _toast(context, 'Slug is already taken');
      } else {
        _toast(context, 'Failed: ${e.message}');
      }
      rethrow;
    } catch (e) {
      _toast(context, 'Error: $e');
      rethrow;
    }
  }

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

  Future<void> editTenant({
    required BuildContext context,
    required String slug,
    String? displayName,
    String? primaryColor,
    String? logoPath,
    Map<String, dynamic>? flags,
  }) async {
    try {
      if (primaryColor != null && primaryColor.trim().isNotEmpty) {
        primaryColor = _normalizeHex(primaryColor);
      }
      await _svc.updateTenant(
        slug: slug,
        displayName: (displayName?.trim().isEmpty ?? true)
            ? null
            : displayName!.trim(),
        primaryColor: (primaryColor?.trim().isEmpty ?? true)
            ? null
            : primaryColor!.trim(),
        logoPath: (logoPath?.trim().isEmpty ?? true) ? null : logoPath!.trim(),
        flags: flags,
      );
      _toast(context, 'Updated "$slug"');
    } catch (e) {
      _toast(context, 'Failed to update: $e');
      rethrow;
    }
  }

  String _normalizeHex(String input) {
    final s = input.trim().toUpperCase();
    return s.startsWith('#') ? s : '#$s';
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
