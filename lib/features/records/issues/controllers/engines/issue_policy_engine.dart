// lib/features/records/issues/engines/issue_policy_engine.dart
import 'package:afyakit/features/records/issues/models/enums/issue_action_enum.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_status_enum.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_type_enum.dart';
import 'package:afyakit/features/records/issues/models/issue_record.dart';
import 'package:afyakit/users/user_manager/extensions/auth_user_x.dart';
import 'package:afyakit/users/user_manager/models/auth_user_model.dart';

class IssuePolicyEngine {
  // ── Permissions (single source of truth) ─────────────────────

  bool isRequesterOrAdmin(AuthUser u, IssueRecord r) =>
      u.uid == r.requestedByUid || u.isAdmin;

  bool canManageFrom(AuthUser u, IssueRecord r) =>
      u.canManageStoreById(r.fromStore);

  bool canManageTo(AuthUser u, IssueRecord r) =>
      u.canManageStoreById(r.toStore);

  bool canDispose(AuthUser u, IssueRecord r) => u.canDisposeFrom(r.fromStore);

  bool isDisposal(IssueRecord r) =>
      r.type == IssueType.dispose ||
      r.toStore.trim().toLowerCase() == 'disposal';

  bool get isApprovedBySomeone => true; // placeholder when needed inline

  // ── Which actions are available? (pure) ──────────────────────
  List<IssueAction> actionsFor({
    required AuthUser user,
    required IssueRecord record,
  }) {
    final status = record.statusEnum;
    final type = record.type;

    final reqOrAdmin = isRequesterOrAdmin(user, record);
    final fromOK = canManageFrom(user, record);
    final toOK = canManageTo(user, record);
    final disposeOK = canDispose(user, record);
    final disposal = isDisposal(record);
    final hasApproval = (record.approvedByUid ?? '').isNotEmpty;

    final out = <IssueAction>[];

    // PENDING
    if (status == IssueStatus.pending) {
      if (fromOK) {
        out
          ..add(IssueAction.approve)
          ..add(IssueAction.reject);
      }
      if (reqOrAdmin) {
        out.add(IssueAction.cancel);
      }
    }

    // APPROVED
    if (status == IssueStatus.approved) {
      if (disposal && disposeOK) {
        out.add(IssueAction.dispose);
      }
      if (type == IssueType.dispense && fromOK) {
        out.add(IssueAction.dispense);
      }
      if (type != IssueType.dispense && !disposal && fromOK) {
        out.add(IssueAction.issue);
      }
      if (reqOrAdmin) {
        out.add(IssueAction.cancel);
      }
    }

    // ISSUED
    if (status == IssueStatus.issued) {
      if (disposal) {
        if (!hasApproval && fromOK) {
          out.add(IssueAction.approve); // approve disposal
        }
        if (hasApproval && disposeOK) {
          out.add(IssueAction.dispose);
        }
      } else {
        if (toOK) {
          out.add(IssueAction.receive);
        }
      }
    }

    return out;
  }
}
