// lib/core/auth/auth_user/extensions/auth_user_x.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/services/user_profile_service.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

import 'package:afyakit/shared/utils/normalize/normalize_string.dart';

import 'package:afyakit/features/inventory/items/inventory_item.dart';
import 'package:afyakit/features/inventory/batches/inventory_batch.dart';

extension AuthUserX on AuthUser {
  bool get isActive => status.isActive;
  bool get isPending => !isActive;
  bool get isMember => true;

  StaffRole? get primaryStaffRole => staffRoles.primaryRole;

  bool get isStaff => isStaffResolved;
  bool get hasStaffWorkspace => isStaff;

  // ─────────────────────────────────────────────
  // Capabilities
  // ─────────────────────────────────────────────

  Set<StaffCapability> get effectiveCapabilities {
    if (!isActive) return const <StaffCapability>{};

    return {
      ...staffRoles.allCapabilities,
      if (isSuperAdmin) ...const {
        StaffCapability.accessAdminPanel,
        StaffCapability.manageUsers,
        StaffCapability.manageTenantSettings,
        StaffCapability.manageBilling,
        StaffCapability.transferOwnership,
        StaffCapability.exportAllData,
        StaffCapability.deleteTenant,
      },
    };
  }

  bool hasCap(StaffCapability cap) => effectiveCapabilities.contains(cap);

  bool hasAnyCap(Iterable<StaffCapability> caps) => caps.any(hasCap);

  bool hasAllCaps(Iterable<StaffCapability> caps) => caps.every(hasCap);

  // ─────────────────────────────────────────────
  // Store access
  // ─────────────────────────────────────────────

  bool canAccessStore(String storeId) {
    if (!isActive || !isStaff) return false;

    if (hasCap(StaffCapability.manageAllStores)) {
      return true;
    }

    final target = storeId.normalize();

    return target.isNotEmpty &&
        stores.any((store) => store.normalize() == target);
  }

  bool hasScopedCap(StaffCapability cap, String storeId) =>
      hasCap(cap) && canAccessStore(storeId);

  // ─────────────────────────────────────────────
  // Inventory items
  // ─────────────────────────────────────────────

  bool canViewItem(InventoryItem item) => isActive && isStaff;

  bool canManageItem(InventoryItem item) =>
      isActive && isStaff && hasCap(StaffCapability.manageSku);

  bool canEditItem(InventoryItem item) => canManageItem(item);

  bool canDeleteItem(InventoryItem item) => canManageItem(item);

  // ─────────────────────────────────────────────
  // Inventory batches
  // ─────────────────────────────────────────────

  bool canViewBatch(InventoryBatch batch) => canAccessStore(batch.storeId);

  bool canManageBatch(InventoryBatch batch) =>
      hasScopedCap(StaffCapability.receiveBatches, batch.storeId);

  bool canEditBatch(InventoryBatch batch) => canManageBatch(batch);

  bool canDeleteBatch(InventoryBatch batch) => canManageBatch(batch);

  bool get canAccessInventory =>
      isActive &&
      isStaff &&
      hasAnyCap(const {
        StaffCapability.manageSku,
        StaffCapability.manageBatches,
        StaffCapability.receiveBatches,
        StaffCapability.manageAllStores,
      });

  // ─────────────────────────────────────────────
  // Stock issues and movements
  // ─────────────────────────────────────────────

  bool canApproveIssueFrom(String storeId) =>
      hasScopedCap(StaffCapability.approveIssues, storeId);

  bool canIssueStockFrom(String storeId) => canAccessStore(storeId);

  bool get canCreateIssueRequest =>
      isActive && isStaff && hasCap(StaffCapability.requestStock);

  bool canDisposeFrom(String storeId) =>
      hasScopedCap(StaffCapability.disposeStock, storeId);

  // ─────────────────────────────────────────────
  // Administration
  // ─────────────────────────────────────────────

  bool get canAccessAdminPanel =>
      isActive && (isSuperAdmin || hasCap(StaffCapability.accessAdminPanel));

  bool get canManageUsers =>
      isActive && (isSuperAdmin || hasCap(StaffCapability.manageUsers));

  bool get canEditUserAccounts => isActive && isSuperAdmin;

  bool get canViewUsers => canEditUserAccounts;

  bool _sameTenant(AuthUser target) => tenantId == target.tenantId;

  bool canManageUser(AuthUser target) =>
      canEditUserRolesFor(target) || canChangeStatusFor(target);

  bool canChangeStatusFor(AuthUser target) =>
      canEditUserAccounts && _sameTenant(target) && uid != target.uid;

  bool canDisableUser(AuthUser target) => canChangeStatusFor(target);

  bool canEditUserStoresFor(AuthUser target) => canChangeStatusFor(target);

  bool canEditUserRolesFor(AuthUser target) {
    if (!isActive || !_sameTenant(target) || activeAppId == null) {
      return false;
    }

    if (isSuperAdmin) return true;
    if (uid == target.uid) return false;

    final targetRoles = target.rolesForApp(activeAppId!);

    if (targetRoles.contains(StaffRole.owner)) {
      return false;
    }

    if (staffRoles.contains(StaffRole.owner)) {
      return true;
    }

    return staffRoles.contains(StaffRole.admin) &&
        !targetRoles.contains(StaffRole.admin);
  }

  // ─────────────────────────────────────────────
  // Professional and retail capabilities
  // ─────────────────────────────────────────────

  bool get canUseProfessionalTools => isStaff;

  bool get canManageSalesDocs => hasCap(StaffCapability.manageSalesDocs);

  bool get canViewSalesDocs => isActive;

  bool get canManageInvoices => canManageSalesDocs;
  bool get canManageQuotes => canManageSalesDocs;

  bool get canEditInvoice => canManageInvoices;
  bool get canDeleteInvoice => canManageInvoices;

  bool get canEditQuote => canManageQuotes;
  bool get canDeleteQuote => canManageQuotes;

  bool get canSendQuote => canManageQuotes;
  bool get canMarkQuoteSent => canManageQuotes;

  bool get canConvertQuoteToInvoice => canManageQuotes && canManageInvoices;

  bool get canViewQuotePdf => canViewSalesDocs;

  // ─────────────────────────────────────────────
  // Claims and profile updates
  // ─────────────────────────────────────────────

  AuthUser withMergedClaims(Map<String, dynamic> tokenClaims) =>
      copyWith(claims: {...?claims, ...tokenClaims});

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
