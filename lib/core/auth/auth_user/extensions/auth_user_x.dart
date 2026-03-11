// lib/core/auth_users/extensions/auth_user_x.dart
//
// ✅ SINGLE SOURCE OF TRUTH:
//   - staff_role_x.dart defines StaffCapability and role->capability mapping.
//   - AuthUserX asks: "does user have capability X? and (if scoped) can access store?"
//
// ✅ No back-compat role predicates.
// ✅ primaryStaffRole exists ONLY for UI tier / mode switching (not permissions).

import 'package:afyakit/core/auth/auth_user/services/user_profile_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/utils/normalize/normalize_string.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';

import 'package:afyakit/features/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/batches/models/batch_record.dart';

extension AuthUserX on AuthUser {
  // ────────────────────────────────────────────
  // Status / identity
  // ────────────────────────────────────────────

  bool get isActive => status.isActive;
  bool get isPending => !isActive;

  /// Everyone is a "member" by default now.
  bool get isMember => true;

  /// UI-only tiering:
  /// - null => member-only
  /// - superadmin => owner tier
  /// - otherwise highest precedence assigned role
  StaffRole? get primaryStaffRole {
    if (isSuperAdmin) return StaffRole.owner;
    return staffRoles.primaryRole;
  }

  bool get isStaff => primaryStaffRole != null;
  bool get isMemberResolved => !isStaff;
  bool get isStaffResolved => isStaff;

  /// Main “second dashboard” toggle.
  bool get hasStaffWorkspace => isStaff;

  // ────────────────────────────────────────────
  // Capabilities (THE ONLY PERMISSION TRUTH)
  // ────────────────────────────────────────────

  /// Effective capabilities for this user.
  /// - inactive => none
  /// - superadmin => owner capability set
  /// - otherwise union of assigned role capabilities
  Set<StaffCapability> get effectiveCapabilities {
    if (!isActive) return const <StaffCapability>{};
    if (isSuperAdmin) return StaffRole.owner.capabilities;
    if (staffRoles.isEmpty) return const <StaffCapability>{};
    return staffRoles.allCapabilities;
  }

  bool hasCap(StaffCapability cap) => effectiveCapabilities.contains(cap);

  bool hasAnyCap(Iterable<StaffCapability> caps) {
    for (final c in caps) {
      if (hasCap(c)) return true;
    }
    return false;
  }

  bool hasAllCaps(Iterable<StaffCapability> caps) {
    for (final c in caps) {
      if (!hasCap(c)) return false;
    }
    return true;
  }

  // ────────────────────────────────────────────
  // Store access
  // ────────────────────────────────────────────

  /// Store access is NOT a capability by itself; it's a membership list,
  /// with an override capability for "all stores".
  bool canAccessStore(String storeId) {
    if (!isActive) return false;

    // Global store access
    if (hasCap(StaffCapability.manageAllStores)) return true;

    final target = storeId.normalize();
    return stores.any((s) => s.normalize() == target);
  }

  /// Capability that is scoped by store access.
  bool hasScopedCap(StaffCapability cap, String storeId) {
    if (!isActive) return false;
    if (!hasCap(cap)) return false;
    return canAccessStore(storeId);
  }

  // ────────────────────────────────────────────
  // Inventory permissions (scoped)
  // ────────────────────────────────────────────

  bool canViewItem(BaseInventoryItem item) => true;

  bool canManageItem(BaseInventoryItem item) =>
      hasScopedCap(StaffCapability.manageSku, item.storeId);

  bool canEditItem(BaseInventoryItem item) => canManageItem(item);
  bool canDeleteItem(BaseInventoryItem item) => canManageItem(item);

  // ────────────────────────────────────────────
  // Batch permissions (scoped)
  // ────────────────────────────────────────────

  bool canViewBatch(BatchRecord batch) => true;

  bool canManageBatch(BatchRecord batch) =>
      hasScopedCap(StaffCapability.receiveBatches, batch.storeId);

  bool canEditBatch(BatchRecord batch) => canManageBatch(batch);
  bool canDeleteBatch(BatchRecord batch) => canManageBatch(batch);

  bool get canAccessInventory =>
      isActive &&
      hasAnyCap(const [
        StaffCapability.manageBatches,
        StaffCapability.receiveBatches,
      ]);

  // ────────────────────────────────────────────
  // Issue workflow permissions (scoped)
  // ────────────────────────────────────────────

  bool canApproveIssueFrom(String fromStoreId) =>
      hasScopedCap(StaffCapability.approveIssues, fromStoreId);

  bool canIssueStockFrom(String storeId) => isActive && canAccessStore(storeId);

  bool get canCreateIssueRequest => true;

  bool canDisposeFrom(String storeId) =>
      hasScopedCap(StaffCapability.disposeStock, storeId);

  // ────────────────────────────────────────────
  // Admin / user management
  // ────────────────────────────────────────────

  bool get canAccessAdminPanel =>
      isActive && hasCap(StaffCapability.accessAdminPanel);

  bool get canManageUsers => isActive && hasCap(StaffCapability.manageUsers);

  bool get canEditUserAccounts => canManageUsers;
  bool get canViewUsers => canAccessAdminPanel;

  /// Single-rule management:
  /// - must have manageUsers
  /// - cannot manage self
  ///
  /// If you later want tier constraints (e.g., admin can’t edit owner),
  /// implement that here using primaryStaffRole.level comparisons (UI tier),
  /// but keep capabilities as the primary gate.
  bool canManageUser(AuthUser target) {
    if (!canManageUsers) return false;
    if (uid == target.uid) return false;
    return true;
  }

  bool canChangeStatusFor(AuthUser target) => canManageUser(target);
  bool canDisableUser(AuthUser target) => canManageUser(target);
  bool canEditUserRolesFor(AuthUser target) => canManageUser(target);
  bool canEditUserStoresFor(AuthUser target) => canManageUser(target);

  // ────────────────────────────────────────────
  // Professional tools
  // ────────────────────────────────────────────

  bool get canUseProfessionalTools => isActive && isStaff;

  // ────────────────────────────────────────────
  // Retail / Zoho permissions
  // ────────────────────────────────────────────

  bool get canManageSalesDocs =>
      isActive && hasCap(StaffCapability.manageSalesDocs);

  /// ✅ Explicit doc-type helpers for clean UI gates.
  /// Today: both map to manageSalesDocs; later you can split capabilities.
  bool get canManageInvoices => canManageSalesDocs;
  bool get canManageQuotes => canManageSalesDocs;

  bool get canEditInvoice => canManageInvoices;
  bool get canDeleteInvoice => canManageInvoices;

  bool get canEditQuote => canManageQuotes;
  bool get canDeleteQuote => canManageQuotes;

  // ────────────────────────────────────────────
  // Claims merge (kept; not a permission source)
  // ────────────────────────────────────────────

  /// Merge token claims into your AuthUser model.
  /// MODEL WINS. Do NOT let stale claims override your migrated data.
  AuthUser withMergedClaims(Map<String, dynamic> tokenClaims) =>
      copyWith(claims: {...(claims ?? const {}), ...tokenClaims});

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
