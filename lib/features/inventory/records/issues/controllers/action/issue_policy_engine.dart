import 'package:afyakit/features/inventory/records/issues/extensions/issue_action_x.dart';
import 'package:afyakit/features/inventory/records/issues/extensions/issue_status_x.dart';
import 'package:afyakit/features/inventory/records/issues/extensions/issue_type_x.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_record.dart';

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final issuePolicyEngineProvider = Provider<IssuePolicyEngine>(
  (ref) => IssuePolicyEngine(),
);

class IssuePolicyEngine {
  // ── Identity ────────────────────────────────────────────────

  bool isRequester(AuthUser u, IssueRecord r) => u.uid == r.requestedByUid;

  // ── Scopes / capabilities (SOT) ─────────────────────────────

  /// Approve/reject is a scoped capability.
  bool canApproveFrom(AuthUser u, IssueRecord r) =>
      u.hasScopedCap(StaffCapability.approveIssues, r.fromStore);

  /// Issuing/dispensing stock requires access to the source store.
  /// (You can tighten this later with an explicit capability if needed.)
  bool canIssueFrom(AuthUser u, IssueRecord r) =>
      u.canIssueStockFrom(r.fromStore);

  /// Receiving is a scoped capability at destination store.
  bool canReceiveTo(AuthUser u, IssueRecord r) =>
      u.hasScopedCap(StaffCapability.receiveBatches, r.toStore);

  /// Disposal requires scoped dispose capability at source store.
  bool canDisposeFrom(AuthUser u, IssueRecord r) =>
      u.canDisposeFrom(r.fromStore);

  /// Cancel is allowed for requester OR the scoped approver for the from-store.
  bool canCancel(AuthUser u, IssueRecord r) =>
      isRequester(u, r) || canApproveFrom(u, r);

  // ── Semantics ───────────────────────────────────────────────

  bool isDisposal(IssueRecord r) =>
      r.type == IssueType.dispose ||
      r.toStore.trim().toLowerCase() == 'disposal';

  // ── Which actions are available? (pure) ──────────────────────

  List<IssueAction> actionsFor({
    required AuthUser user,
    required IssueRecord record,
  }) {
    final status = record.statusEnum;
    final type = record.type;

    final requester = isRequester(user, record);
    final approvalOK = canApproveFrom(user, record);
    final issueOK = canIssueFrom(user, record);
    final receiveOK = canReceiveTo(user, record);
    final disposeOK = canDisposeFrom(user, record);

    final disposal = isDisposal(record);
    final hasApproval = (record.approvedByUid ?? '').trim().isNotEmpty;

    final out = <IssueAction>[];

    // PENDING
    if (status == IssueStatus.pending) {
      if (approvalOK) {
        out
          ..add(IssueAction.approve)
          ..add(IssueAction.reject);
      }
      if (requester || approvalOK) {
        out.add(IssueAction.cancel);
      }
    }

    // APPROVED
    if (status == IssueStatus.approved) {
      if (disposal) {
        if (disposeOK) out.add(IssueAction.dispose);
      } else if (type == IssueType.dispense) {
        if (issueOK) out.add(IssueAction.dispense);
      } else {
        // transfer / other non-dispense, non-disposal
        if (issueOK) out.add(IssueAction.issue);
      }

      if (requester || approvalOK) {
        out.add(IssueAction.cancel);
      }
    }

    // ISSUED
    if (status == IssueStatus.issued) {
      if (disposal) {
        // Some flows may "issue" first then approve+dispose.
        if (!hasApproval && approvalOK) {
          out.add(IssueAction.approve);
        }
        if (hasApproval && disposeOK) {
          out.add(IssueAction.dispose);
        }
      } else {
        if (receiveOK) {
          out.add(IssueAction.receive);
        }
      }
    }

    return out;
  }
}
