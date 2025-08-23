// lib/users/extensions/auth_user_x.dart
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:afyakit/features/auth_users/user_manager/extensions/user_status_x.dart';
import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:afyakit/features/auth_users/user_manager/extensions/user_role_x.dart';
import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';

extension AuthUserX on AuthUser {
  // status
  UserStatus get statusEnum => UserStatus.fromString(status);
  bool get isActive => statusEnum.isActive;
  bool get isInvited => statusEnum.isInvited;
  bool get isPending => !isActive;

  // 👇 MODEL WINS. Do NOT let stale claims override your migrated data.
  UserRole get effectiveRole => role;

  bool get isAdmin => effectiveRole.isAdmin;
  bool get isManager => effectiveRole.isManager;
  bool get isStaff => effectiveRole.isStaff;
  bool get isManagerOrAdmin => isSuperAdmin || isAdmin || isManager;

  bool canAccessStore(String storeId) {
    if (isSuperAdmin || effectiveRole.canManageAllStores) return true;
    final target = storeId.normalize();
    return stores.any((s) => s.normalize() == target);
  }

  bool hasScopedPermission(bool Function(UserRole) predicate, String storeId) =>
      isActive &&
      (isSuperAdmin || predicate(effectiveRole)) &&
      canAccessStore(storeId);

  bool canManageStoreById(String storeId) =>
      hasScopedPermission((r) => r.canManageSku, storeId);

  // inventory/batches (unchanged)
  bool canViewItem(BaseInventoryItem item) => true;
  bool canManageItem(BaseInventoryItem item) =>
      hasScopedPermission((r) => r.canManageSku, item.storeId);
  bool canEditItem(BaseInventoryItem item) => canManageItem(item);
  bool canDeleteItem(BaseInventoryItem item) => canManageItem(item);

  bool canViewBatch(BatchRecord batch) => true;
  bool canManageBatch(BatchRecord batch) =>
      hasScopedPermission((r) => r.canReceiveBatches, batch.storeId);
  bool canEditBatch(BatchRecord batch) => canManageBatch(batch);
  bool canDeleteBatch(BatchRecord batch) => canManageBatch(batch);

  bool canApproveIssueFrom(String fromStoreId) =>
      hasScopedPermission((r) => r.canApproveIssues, fromStoreId);
  bool canIssueStockFrom(String storeId) => isActive && canAccessStore(storeId);
  bool get canCreateIssueRequest => true;
  bool canDisposeFrom(String storeId) =>
      hasScopedPermission((r) => r.canDisposeStock, storeId);

  bool get canManageUsers =>
      isActive && (isSuperAdmin || effectiveRole.canManageUsers);
  bool get canEditUserAccounts => canManageUsers;
  bool get canViewUsers => isActive && (isSuperAdmin || isAdmin || isManager);
  bool get canAccessAdminPanel =>
      isSuperAdmin || effectiveRole.canAccessAdminPanel;
}
