// lib/core/auth_users/extensions/auth_user_x.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/utils/normalize/normalize_string.dart';

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';
import 'package:afyakit/core/auth_users/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth_users/extensions/user_type_x.dart';
import 'package:afyakit/core/auth_users/services/auth_service.dart';

import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/core/batches/models/batch_record.dart';

extension AuthUserX on AuthUser {
  // ────────────────────────────────────────────
  // Claims / type / roles
  // ────────────────────────────────────────────

  /// Merge token claims into your AuthUser model.
  /// MODEL WINS. Do NOT let stale claims override your migrated data.
  AuthUser withMergedClaims(Map<String, dynamic> tokenClaims) =>
      copyWith(claims: {...(claims ?? const {}), ...tokenClaims});

  // status (enum-aware)
  bool get isActive => status.isActive;
  bool get isPending => !isActive;

  /// Everyone is a member in your model.
  bool get isMember => type.isMember;

  /// High-level staff flag:
  /// - explicit `type.staff`
  /// - OR presence of staff roles
  /// - OR superadmin
  bool get isStaff => type.isStaff || staffRoles.isNotEmpty || isSuperAdmin;

  /// Convenience accessors derived from staffRoles (+ superadmin)
  bool get isOwner => isSuperAdmin || staffRoles.any((r) => r.isOwner);
  bool get isAdmin => isSuperAdmin || staffRoles.any((r) => r.isAdmin);
  bool get isManager => staffRoles.any((r) => r.isManager);
  bool get isRider => staffRoles.any((r) => r.isRider);
  bool get isDoctor => staffRoles.any((r) => r.isDoctor);
  bool get isPharmacist => staffRoles.any((r) => r.isPharmacist);
  bool get isNurse => staffRoles.any((r) => r.isNurse);
  bool get isDispatcher => staffRoles.any((r) => r.isDispatcher);

  bool get isManagerOrAdmin => isSuperAdmin || isAdmin || isManager;

  /// Governance in the tenant (owner or admin).
  bool get isGovernance => isOwner || isAdmin;

  /// Main “second dashboard” toggle.
  bool get hasStaffWorkspace => type.hasStaffWorkspace || isStaff;

  // ────────────────────────────────────────────
  // Internal helpers
  // ────────────────────────────────────────────

  /// True if *any* staff role satisfies the given predicate.
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
  // Inventory / item permissions
  // ────────────────────────────────────────────

  bool canViewItem(BaseInventoryItem item) => true;

  bool canManageItem(BaseInventoryItem item) =>
      hasScopedPermission((r) => r.canManageSku, item.storeId);

  bool canEditItem(BaseInventoryItem item) => canManageItem(item);

  bool canDeleteItem(BaseInventoryItem item) => canManageItem(item);

  // ────────────────────────────────────────────
  // Batch / stock permissions
  // ────────────────────────────────────────────

  bool canViewBatch(BatchRecord batch) => true;

  bool canManageBatch(BatchRecord batch) =>
      hasScopedPermission((r) => r.canReceiveBatches, batch.storeId);

  bool canEditBatch(BatchRecord batch) => canManageBatch(batch);

  bool canDeleteBatch(BatchRecord batch) => canManageBatch(batch);

  /// High-level inventory gate for nav / screen access.
  bool get canAccessInventory =>
      isSuperAdmin ||
      _anyRole((r) => r.canManageBatches || r.canReceiveBatches) ||
      isPharmacist;

  // ────────────────────────────────────────────
  // Issue / workflow permissions
  // ────────────────────────────────────────────

  bool canApproveIssueFrom(String fromStoreId) =>
      hasScopedPermission((r) => r.canApproveIssues, fromStoreId);

  bool canIssueStockFrom(String storeId) => isActive && canAccessStore(storeId);

  bool get canCreateIssueRequest => true; // any logged-in user

  bool canDisposeFrom(String storeId) =>
      hasScopedPermission((r) => r.canDisposeStock, storeId);

  // ────────────────────────────────────────────
  // User management / admin panel
  // ────────────────────────────────────────────

  /// Old coarse gate: "can see user management at all".
  bool get canManageUsers =>
      isActive && (isSuperAdmin || _anyRole((r) => r.canManageUsers));

  bool get canEditUserAccounts => canManageUsers;

  bool get canViewUsers => isActive && (isSuperAdmin || isAdmin || isManager);

  bool get canAccessAdminPanel =>
      isSuperAdmin || _anyRole((r) => r.canAccessAdminPanel);

  /// Pair-wise: can this user *manage* [target] in the user manager?
  ///
  /// Rules:
  /// - must be active themself
  /// - superadmin → can manage anyone
  /// - owner      → can manage anyone (including other owners)
  /// - admin      → can manage any non-owner (including other admins and self)
  /// - others     → cannot manage users
  bool canManageUser(AuthUser target) {
    if (!isActive) return false;

    // Superadmin can always manage.
    if (isSuperAdmin) return true;

    // Owners can manage anyone, including other owners and themselves.
    if (isOwner) return true;

    // Admins:
    if (isAdmin) {
      // Admins cannot manage owners.
      if (target.isOwner) return false;
      // But they can manage themselves and other non-owners.
      return true;
    }

    // Managers/others cannot manage users.
    return false;
  }

  /// Can this user change status (active/disabled) for [target] at all?
  /// More specific rules (like self-disable) are handled in [canDisableUser].
  bool canChangeStatusFor(AuthUser target) => canManageUser(target);

  /// Can this user set [target] to disabled?
  ///
  /// Rules:
  /// - must be allowed to manage target
  /// - cannot disable themselves (no self-lockout)
  /// - only owner/superadmin can disable an owner
  bool canDisableUser(AuthUser target) {
    if (!canManageUser(target)) return false;

    // No self-disable for safety.
    if (uid == target.uid) return false;

    // Only governance above or equal can disable an owner.
    if (target.isOwner && !(isSuperAdmin || isOwner)) {
      return false;
    }

    return true;
  }

  /// Can this user edit staffRoles[] for [target] **at all**?
  ///
  /// Rules:
  /// - must be allowed to manage target
  /// - owner / superadmin → can edit anyone's roles
  /// - admin → can edit roles for non-owners
  /// - others → no
  bool canEditUserRolesFor(AuthUser target) {
    if (!canManageUser(target)) return false;

    if (isSuperAdmin || isOwner) return true;

    if (isAdmin) {
      if (target.isOwner) return false;
      return true;
    }

    return false;
  }

  /// Can this user edit store assignments for [target]?
  ///
  /// Rules:
  /// - same shape as roles for now:
  ///   - owner/superadmin → can edit anyone
  ///   - admin → can edit non-owners
  bool canEditUserStoresFor(AuthUser target) {
    if (!canManageUser(target)) return false;

    if (isSuperAdmin || isOwner) return true;

    if (isAdmin) {
      if (target.isOwner) return false;
      return true;
    }

    return false;
  }

  /// Professional tools (clinical / operational side; extra convenience)
  bool get canUseProfessionalTools =>
      isDoctor || isPharmacist || isStaff || isSuperAdmin;

  // ────────────────────────────────────────────
  // Remote update helper (tenant-scoped PATCH)
  // ────────────────────────────────────────────

  /// Tenant-scoped update hook:
  /// PATCH /tenants/{tenantId}/auth_users/{uid}
  Future<void> updateFields(Ref ref, Map<String, dynamic> fields) async {
    final service = await ref.read(authServiceProvider(tenantId).future);
    await service.updateUserFields(uid, fields);
  }
}
