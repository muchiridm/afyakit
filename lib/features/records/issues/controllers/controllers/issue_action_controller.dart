// lib/features/records/issues/controllers/issue_action_controller.dart

import 'package:afyakit/features/records/issues/controllers/controllers/issue_lifecycle_controller.dart';
import 'package:afyakit/features/records/issues/controllers/engines/issue_policy_engine.dart';
import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_action_enum.dart';

import 'package:afyakit/features/records/issues/models/issue_record.dart';
import 'package:afyakit/features/records/issues/models/view_models/issue_action_button.dart';
import 'package:afyakit/features/records/issues/services/issue_batch_service.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/users/providers/current_user_provider.dart';

// NEW: policy provider
import 'package:afyakit/features/records/issues/providers/issue_engine_providers.dart';

final issueActionControllerProvider = Provider<IssueActionController?>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  final user = ref.watch(currentUserProvider).asData?.value;
  if (user == null) return null;

  final lifecycle = IssueLifecycleController(
    ref: ref,
    tenantId: tenantId,
    currentUser: user,
  );

  final batchService = IssueBatchService(tenantId: tenantId, ref: ref);

  // NEW: read policy engine
  final policy = ref.read(issuePolicyEngineProvider);

  return IssueActionController(
    lifecycle: lifecycle,
    batchService: batchService,
    policy: policy,
  );
});

class IssueActionController {
  final IssueLifecycleController lifecycle;
  final IssueBatchService batchService;
  final IssuePolicyEngine policy;

  IssueActionController({
    required this.lifecycle,
    required this.batchService,
    required this.policy,
  });

  // Map action → label/icon used to build buttons (kept identical)
  static const _labels = <IssueAction, String>{
    IssueAction.approve: 'Approve',
    IssueAction.reject: 'Reject',
    IssueAction.cancel: 'Cancel Request',
    IssueAction.issue: 'Mark as Issued',
    IssueAction.receive: 'Mark as Received',
    IssueAction.dispose: 'Mark as Disposed',
    IssueAction.dispense: 'Mark as Dispensed',
  };

  static const _icons = <IssueAction, IconData>{
    IssueAction.approve: Icons.check_circle_outline,
    IssueAction.reject: Icons.cancel_outlined,
    IssueAction.cancel: Icons.undo,
    IssueAction.issue: Icons.inventory,
    IssueAction.receive: Icons.check_circle,
    IssueAction.dispose: Icons.delete_forever,
    IssueAction.dispense: Icons.medical_services_outlined,
  };

  // Minimal UI wrapper → calls lifecycle (unchanged behavior)
  Future<void> _execute(BuildContext ctx, IssueAction a, IssueRecord r) {
    switch (a) {
      case IssueAction.approve:
        return lifecycle.approve(ctx, r);
      case IssueAction.reject:
        return lifecycle.reject(ctx, r);
      case IssueAction.cancel:
        return lifecycle.cancel(ctx, r);
      case IssueAction.issue:
        return lifecycle.markAsIssued(ctx, r);
      case IssueAction.receive:
        return lifecycle.markAsReceived(ctx, r);
      case IssueAction.dispose:
        return lifecycle.markAsDisposed(ctx, r);
      case IssueAction.dispense:
        return lifecycle.markAsDispensed(ctx, r, 'Dispensed via UI action');
    }
  }

  List<IssueActionButton> getAvailableActions({
    required AuthUser user,
    required IssueRecord record,
    required List<InventoryLocation> allStores, // kept for signature parity
  }) {
    // NEW: ask the policy which actions are allowed
    final actions = policy.actionsFor(user: user, record: record);

    // Build buttons exactly like before
    return actions.map((a) {
      return IssueActionButton(
        label: _labels[a]!,
        icon: _icons[a]!,
        color: getIssueActionColor(a),
        onPressed: (ctx) => _execute(ctx, a, record),
      );
    }).toList();
  }
}
