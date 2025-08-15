import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:afyakit/users/extensions/user_role_x.dart';
import 'package:afyakit/users/extensions/auth_user_status_enum.dart';
import 'package:afyakit/users/models/combined_user_model.dart';
import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/users/extensions/user_role_enum.dart';

extension CombinedUserX on CombinedUser {
  // Status
  bool get isActive => status == AuthUserStatus.active;
  bool get isInvited => status == AuthUserStatus.invited;
  bool get isPending => !isActive;

  // Role shortcuts
  bool get isAdmin => role.isAdmin;
  bool get isManager => role.isManager;
  bool get isManagerOrAdmin =>
      isSuperAdmin || isAdmin || isManager; // 👈 super wins
  bool get isStaff => role.isStaff;
  bool get isViewOnly => role.isViewOnly;

  // Store access
  bool canAccessStore(String storeId) {
    if (isSuperAdmin) return true; // 👈 super wins
    final normalizedTarget = storeId.normalize();
    return isAdmin || stores.any((s) => s.normalize() == normalizedTarget);
  }

  bool hasScopedPermission(
    bool Function(UserRole role) predicate,
    String storeId,
  ) =>
      isActive &&
      (isSuperAdmin || predicate(role)) &&
      canAccessStore(storeId); // 👈

  bool canManageStoreById(String storeId) =>
      hasScopedPermission((r) => r.canManageSku, storeId);

  // Inventory items
  bool canViewItem(BaseInventoryItem item) => true;
  bool canManageItem(BaseInventoryItem item) =>
      hasScopedPermission((r) => r.canManageSku, item.storeId);
  bool canEditItem(BaseInventoryItem item) => canManageItem(item);
  bool canDeleteItem(BaseInventoryItem item) => canManageItem(item);

  // Batches
  bool canViewBatch(BatchRecord batch) => true;
  bool canManageBatch(BatchRecord batch) =>
      hasScopedPermission((r) => r.canReceiveBatches, batch.storeId);
  bool canEditBatch(BatchRecord batch) => canManageBatch(batch);
  bool canDeleteBatch(BatchRecord batch) => canManageBatch(batch);

  bool canAddBatch(BaseInventoryItem item) =>
      isActive &&
      (isSuperAdmin ||
          isAdmin ||
          hasScopedPermission((r) => r.canReceiveBatches, item.storeId));

  // Issues
  bool canApproveIssueFrom(String fromStoreId) =>
      hasScopedPermission((r) => r.canApproveIssues, fromStoreId);
  bool canIssueStockFrom(String storeId) => isActive && canAccessStore(storeId);
  bool get canCreateIssueRequest => true;
  bool canDisposeFrom(String storeId) =>
      hasScopedPermission((r) => r.canDisposeStock, storeId);

  // User management
  bool get canManageUsers => isActive && (isSuperAdmin || role.canManageUsers);
  bool get canEditUserAccounts => canManageUsers;
  bool get canViewUsers => isActive && (isSuperAdmin || isAdmin || isManager);

  // Reporting
  bool get canViewReports => true; // unchanged

  // Admin panel access
  bool get canAccessAdminPanel =>
      isSuperAdmin || role.canAccessAdminPanel; // 👈
}
