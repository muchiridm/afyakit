// lib/features/records/issues/controllers/issue_action_controller.dart

import 'package:afyakit/features/records/issues/controllers/controllers/issue_lifecycle_controller.dart';
import 'package:afyakit/features/records/issues/controllers/engines/issue_policy_engine.dart';
import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_action_enum.dart';

import 'package:afyakit/features/records/issues/models/issue_record.dart';
import 'package:afyakit/features/records/issues/models/view_models/issue_action_button.dart';
import 'package:afyakit/features/records/issues/services/issue_batch_service.dart';
import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/features/auth_users/providers/current_user_session_providers.dart';

// NEW: policy provider
import 'package:afyakit/features/records/issues/providers/issue_engine_providers.dart';

final issueActionControllerProvider = Provider<IssueActionController?>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  final user = ref.watch(currentUserProvider).asData?.value;
  if (user == null) {
    if (kDebugMode) {
      debugPrint(
        '[IssueActionController] user=null (tenant=$tenantId) → not ready',
      );
    }
    return null;
  }

  if (kDebugMode) {
    debugPrint(
      '[IssueActionController] init tenant=$tenantId '
      'user=${user.uid} role=${user.role.name}',
    );
  }

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

  // Minimal UI wrapper → calls lifecycle (now with robust logs + error surfacing)
  Future<void> _execute(BuildContext ctx, IssueAction a, IssueRecord r) async {
    if (kDebugMode) {
      debugPrint(
        '[Action] TAP "${_labels[a]}" issue=${r.id} status=${r.status}',
      );
    }
    try {
      switch (a) {
        case IssueAction.approve:
          await lifecycle.approve(ctx, r);
          break;
        case IssueAction.reject:
          await lifecycle.reject(ctx, r);
          break;
        case IssueAction.cancel:
          await lifecycle.cancel(ctx, r);
          break;
        case IssueAction.issue:
          await lifecycle.markAsIssued(ctx, r);
          break;
        case IssueAction.receive:
          await lifecycle.markAsReceived(ctx, r);
          break;
        case IssueAction.dispose:
          await lifecycle.markAsDisposed(ctx, r);
          break;
        case IssueAction.dispense:
          await lifecycle.markAsDispensed(ctx, r, 'Dispensed via UI action');
          break;
      }
      if (kDebugMode) {
        debugPrint('[Action] DONE "${_labels[a]}" issue=${r.id}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Action][ERR] "${_labels[a]}" issue=${r.id}: $e\n$st');
      }
      rethrow; // let caller show a snack if they want
    }
  }

  List<IssueActionButton> getAvailableActions({
    required AuthUser user,
    required IssueRecord record,
    required List<InventoryLocation> allStores, // kept for signature parity
  }) {
    // NEW: ask the policy which actions are allowed
    final actions = policy.actionsFor(user: user, record: record);

    if (kDebugMode) {
      debugPrint(
        '[Actions] resolve user=${user.uid} role=${user.role.name} '
        'issue=${record.id} status=${record.status} '
        'from=${record.fromStore} to=${record.toStore} '
        'stores=${allStores.length} '
        '→ [${actions.map((a) => _labels[a]).join(', ')}]',
      );
    }

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
