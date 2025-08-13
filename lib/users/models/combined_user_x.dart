import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:afyakit/users/models/user_role_x.dart';
import 'package:afyakit/users/models/auth_user_status_enum.dart';
import 'package:afyakit/users/models/combined_user.dart';
import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/users/models/user_role_enum.dart';

extension CombinedUserX on CombinedUser {
  // ─────────────────────────────────────────────
  // 🔐 Auth Status
  // ─────────────────────────────────────────────
  bool get isActive => status == AuthUserStatus.active;
  bool get isInvited => status == AuthUserStatus.invited;
  bool get isPending => !isActive;

  // ─────────────────────────────────────────────
  // 🧑 Role Shortcuts
  // ─────────────────────────────────────────────
  bool get isAdmin => role.isAdmin;
  bool get isManager => role.isManager;
  bool get isManagerOrAdmin => isAdmin || isManager;
  bool get isStaff => role.isStaff;
  bool get isViewOnly => role.isViewOnly;

  // ─────────────────────────────────────────────
  // 🏪 Store Access
  // ─────────────────────────────────────────────
  bool canAccessStore(String storeId) {
    final normalizedTarget = storeId.normalize();
    final access =
        isAdmin || stores.any((s) => s.normalize() == normalizedTarget);

    return access;
  }

  bool hasScopedPermission(
    bool Function(UserRole role) predicate,
    String storeId,
  ) => isActive && predicate(role) && canAccessStore(storeId);

  bool canManageStoreById(String storeId) =>
      hasScopedPermission((r) => r.canManageSku, storeId);

  // ─────────────────────────────────────────────
  // 📦 Inventory Items (SKUs)
  // ─────────────────────────────────────────────
  bool canViewItem(BaseInventoryItem item) => true;

  bool canManageItem(BaseInventoryItem item) =>
      hasScopedPermission((r) => r.canManageSku, item.storeId);

  bool canEditItem(BaseInventoryItem item) => canManageItem(item);
  bool canDeleteItem(BaseInventoryItem item) => canManageItem(item);

  // ─────────────────────────────────────────────
  // 🧾 Batch Records
  // ─────────────────────────────────────────────
  bool canViewBatch(BatchRecord batch) => true;

  bool canManageBatch(BatchRecord batch) =>
      hasScopedPermission((r) => r.canReceiveBatches, batch.storeId);

  bool canEditBatch(BatchRecord batch) => canManageBatch(batch);
  bool canDeleteBatch(BatchRecord batch) => canManageBatch(batch);

  bool canAddBatch(BaseInventoryItem item) =>
      isActive &&
      (isAdmin ||
          hasScopedPermission((r) => r.canReceiveBatches, item.storeId));

  // ─────────────────────────────────────────────
  // 🚚 Issue Operations
  // ─────────────────────────────────────────────
  bool canApproveIssueFrom(String fromStoreId) =>
      hasScopedPermission((r) => r.canApproveIssues, fromStoreId);

  bool canIssueStockFrom(String storeId) => isActive && canAccessStore(storeId);

  bool get canCreateIssueRequest => true;

  bool canDisposeFrom(String storeId) =>
      hasScopedPermission((r) => r.canDisposeStock, storeId);

  // ─────────────────────────────────────────────
  // 🧑‍💻 User Management
  // ─────────────────────────────────────────────
  bool get canManageUsers => isActive && role.canManageUsers;
  bool get canEditUserAccounts => canManageUsers;
  bool get canViewUsers => isActive && (isAdmin || isManager);

  // ─────────────────────────────────────────────
  // 📊 Reporting
  // ─────────────────────────────────────────────
  bool get canViewReports => role.canViewReports;

  // ─────────────────────────────────────────────
  // 🏪 Admin Panel Access
  // ─────────────────────────────────────────────
  bool get canAccessAdminPanel => role.canAccessAdminPanel;
}
