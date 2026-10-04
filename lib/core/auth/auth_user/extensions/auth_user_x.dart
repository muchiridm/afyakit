// lib/core/auth/auth_user/extensions/auth_user_x.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/auth/auth_user/services/user_profile_service.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:afyakit/features/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/batches/models/batch_record.dart';

extension AuthUserX on AuthUser {
  bool get isActive => status.isActive;
  bool get isPending => !isActive;
  bool get isMember => true;
  StaffRole? get primaryStaffRole => staffRoles.primaryRole;
  bool get isStaff => isStaffResolved;
  bool get hasStaffWorkspace => isStaff;

  /// App capabilities come only from assignments in the bound app.
  /// Platform administration grants no clinical/retail staff capabilities.
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

  bool canAccessStore(String storeId) {
    if (!isActive || !isStaff) return false;
    if (hasCap(StaffCapability.manageAllStores)) return true;
    final target = storeId.normalize();
    return target.isNotEmpty &&
        stores.any((store) => store.normalize() == target);
  }

  bool hasScopedCap(StaffCapability cap, String storeId) =>
      hasCap(cap) && canAccessStore(storeId);
  bool canViewItem(BaseInventoryItem item) => true;
  bool canManageItem(BaseInventoryItem item) =>
      hasScopedCap(StaffCapability.manageSku, item.storeId);
  bool canEditItem(BaseInventoryItem item) => canManageItem(item);
  bool canDeleteItem(BaseInventoryItem item) => canManageItem(item);
  bool canViewBatch(BatchRecord batch) => canAccessStore(batch.storeId);
  bool canManageBatch(BatchRecord batch) =>
      hasScopedCap(StaffCapability.receiveBatches, batch.storeId);
  bool canEditBatch(BatchRecord batch) => canManageBatch(batch);
  bool canDeleteBatch(BatchRecord batch) => canManageBatch(batch);
  bool get canAccessInventory => hasAnyCap(const [
    StaffCapability.manageBatches,
    StaffCapability.receiveBatches,
  ]);
  bool canApproveIssueFrom(String storeId) =>
      hasScopedCap(StaffCapability.approveIssues, storeId);
  bool canIssueStockFrom(String storeId) => canAccessStore(storeId);
  bool get canCreateIssueRequest => hasCap(StaffCapability.requestStock);
  bool canDisposeFrom(String storeId) =>
      hasScopedCap(StaffCapability.disposeStock, storeId);

  // Tenant-wide account APIs in the aligned backend require platform admin.
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
    if (!isActive || !_sameTenant(target) || activeAppId == null) return false;
    if (isSuperAdmin) return true;
    if (uid == target.uid) return false;
    final targetRoles = target.rolesForApp(activeAppId!);
    if (targetRoles.contains(StaffRole.owner)) return false;
    if (staffRoles.contains(StaffRole.owner)) return true;
    return staffRoles.contains(StaffRole.admin) &&
        !targetRoles.contains(StaffRole.admin);
  }

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

  AuthUser withMergedClaims(Map<String, dynamic> tokenClaims) =>
      copyWith(claims: {...(claims ?? const {}), ...tokenClaims});
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
