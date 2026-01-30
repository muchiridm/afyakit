// lib/core/auth_users/extensions/auth_user_x.dart

import 'package:afyakit/core/auth/auth_user/services/user_profile_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/utils/normalize/normalize_string.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';

import 'package:afyakit/features/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/batches/models/batch_record.dart';

extension AuthUserX on AuthUser {
  // ────────────────────────────────────────────
  // Claims / type / roles
  // ────────────────────────────────────────────

  /// Merge token claims into your AuthUser model.
  /// MODEL WINS. Do NOT let stale claims override your migrated data.
  AuthUser withMergedClaims(Map<String, dynamic> tokenClaims) =>
      copyWith(claims: {...(claims ?? const {}), ...tokenClaims});

  bool get isActive => status.isActive;
  bool get isPending => !isActive;

  /// Everyone is a member in your model.
  bool get isMember => type.isMember;

  /// High-level staff flag:
  /// - explicit `type.staff`
  /// - OR presence of staff roles
  /// - OR superadmin
  bool get isStaff => type.isStaff || staffRoles.isNotEmpty || isSuperAdmin;

  // Derived convenience flags using updated StaffRoleX
  bool get isOwner => isSuperAdmin || staffRoles.any((r) => r.isOwner);
  bool get isAdmin => isSuperAdmin || staffRoles.any((r) => r.isAdmin);
  bool get isManager => staffRoles.any((r) => r.isManager);

  bool get isRunner => staffRoles.contains(StaffRole.runner);
  bool get isDispatcher => staffRoles.contains(StaffRole.dispatcher);
  bool get isDoctor => staffRoles.contains(StaffRole.prescriber);
  bool get isPharmacist => staffRoles.contains(StaffRole.pharmacist);

  bool get isManagerOrAdmin => isSuperAdmin || isAdmin || isManager;

  /// Governance (owner or admin)
  bool get isGovernance => isOwner || isAdmin;

  /// Main “second dashboard” toggle.
  bool get hasStaffWorkspace => type.hasStaffWorkspace || isStaff;

  // Internal helper
  bool _anyRole(bool Function(StaffRole) predicate) =>
      staffRoles.any(predicate);

  // ────────────────────────────────────────────
  // Store access helpers
  // ────────────────────────────────────────────

  bool canAccessStore(String storeId) {
    if (isSuperAdmin || _anyRole((r) => r.canManageAllStores)) return true;
    final target = storeId.normalize();
    return stores.any((s) => s.normalize() == target);
  }

  bool hasScopedPermission(
    bool Function(StaffRole) predicate,
    String storeId,
  ) =>
      isActive &&
      (isSuperAdmin || _anyRole(predicate)) &&
      canAccessStore(storeId);

  bool canManageStoreById(String storeId) =>
      hasScopedPermission((r) => r.canManageSku, storeId);

  // ────────────────────────────────────────────
  // Inventory permissions
  // ────────────────────────────────────────────

  bool canViewItem(BaseInventoryItem item) => true;

  bool canManageItem(BaseInventoryItem item) =>
      hasScopedPermission((r) => r.canManageSku, item.storeId);

  bool canEditItem(BaseInventoryItem item) => canManageItem(item);
  bool canDeleteItem(BaseInventoryItem item) => canManageItem(item);

  // ────────────────────────────────────────────
  // Batch permissions
  // ────────────────────────────────────────────

  bool canViewBatch(BatchRecord batch) => true;

  bool canManageBatch(BatchRecord batch) =>
      hasScopedPermission((r) => r.canReceiveBatches, batch.storeId);

  bool canEditBatch(BatchRecord batch) => canManageBatch(batch);
  bool canDeleteBatch(BatchRecord batch) => canManageBatch(batch);

  bool get canAccessInventory =>
      isSuperAdmin ||
      _anyRole((r) => r.canManageBatches || r.canReceiveBatches) ||
      isPharmacist;

  // ────────────────────────────────────────────
  // Issue workflow permissions
  // ────────────────────────────────────────────

  bool canApproveIssueFrom(String fromStoreId) =>
      hasScopedPermission((r) => r.canApproveIssues, fromStoreId);

  bool canIssueStockFrom(String storeId) => isActive && canAccessStore(storeId);

  bool get canCreateIssueRequest => true;

  bool canDisposeFrom(String storeId) =>
      hasScopedPermission((r) => r.canDisposeStock, storeId);

  // ────────────────────────────────────────────
  // User management / admin panel
  // ────────────────────────────────────────────

  bool get canManageUsers =>
      isActive && (isSuperAdmin || _anyRole((r) => r.canManageUsers));

  bool get canEditUserAccounts => canManageUsers;

  bool get canViewUsers => isActive && (isSuperAdmin || isAdmin || isManager);

  bool get canAccessAdminPanel =>
      isSuperAdmin || _anyRole((r) => r.canAccessAdminPanel);

  bool canManageUser(AuthUser target) {
    if (!isActive) return false;

    if (isSuperAdmin) return true;

    if (isOwner) return true;

    if (isAdmin) {
      if (target.isOwner) return false;
      return true;
    }

    return false;
  }

  bool canChangeStatusFor(AuthUser target) => canManageUser(target);

  bool canDisableUser(AuthUser target) {
    if (!canManageUser(target)) return false;
    if (uid == target.uid) return false;

    if (target.isOwner && !(isSuperAdmin || isOwner)) {
      return false;
    }

    return true;
  }

  bool canEditUserRolesFor(AuthUser target) {
    if (!canManageUser(target)) return false;

    if (isSuperAdmin || isOwner) return true;

    if (isAdmin) {
      if (target.isOwner) return false;
      return true;
    }

    return false;
  }

  bool canEditUserStoresFor(AuthUser target) {
    if (!canManageUser(target)) return false;

    if (isSuperAdmin || isOwner) return true;

    if (isAdmin) {
      if (target.isOwner) return false;
      return true;
    }

    return false;
  }

  /// Clinical/operational tools access
  bool get canUseProfessionalTools =>
      isDoctor || isPharmacist || isStaff || isSuperAdmin;

  // ────────────────────────────────────────────
  // Retail / Zoho permissions
  // ────────────────────────────────────────────

  /// Only managers/admins/owners (or superadmin) can edit/delete invoices.
  bool get canManageInvoices =>
      isActive && (isSuperAdmin || isOwner || isAdmin || isManager);

  bool get canEditInvoice => canManageInvoices;
  bool get canDeleteInvoice => canManageInvoices;

  // ────────────────────────────────────────────
  // Remote update helper
  // ────────────────────────────────────────────

  Future<void> updateFields(
    Ref ref, {
    required String tenantId,
    required String uid,
    required Map<String, dynamic> fields,
  }) async {
    final service = await ref.read(userProfileServiceProvider(tenantId).future);

    await service.updateUserFields(uid, fields);
  }
}
