// lib/features/inventory/records/issues/controllers/action/issue_action_controller.dart

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/auth/auth_user/utils/user_format.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import 'package:afyakit/features/inventory/locations/inventory_location.dart';

import 'package:afyakit/features/inventory/records/issues/controllers/action/issue_policy_engine.dart';
import 'package:afyakit/features/inventory/records/issues/controllers/lifecycle/issue_lifecycle_controller.dart';

import 'package:afyakit/features/inventory/records/issues/extensions/issue_action_x.dart';

import 'package:afyakit/features/inventory/records/issues/models/issue_record.dart';
import 'package:afyakit/features/inventory/records/issues/widgets/issue_action_button.dart';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final issueActionControllerProvider = Provider<IssueActionController?>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  final user = ref.watch(currentUserProvider).asData?.value;

  if (user == null) {
    if (kDebugMode) {
      debugPrint(
        '[IssueActionController] '
        'user=null (tenant=$tenantId) → not ready',
      );
    }

    return null;
  }

  if (kDebugMode) {
    final primaryRole = staffRoleLabel(user);

    final staffRolesStr = user.staffRoles.isEmpty
        ? '-'
        : user.staffRoles.map((role) => role.name).join(', ');

    debugPrint(
      '[IssueActionController] '
      'init tenant=$tenantId '
      'user=${user.uid} '
      'role=$primaryRole '
      'staffRoles=[$staffRolesStr]',
    );
  }

  final lifecycle = IssueLifecycleController(ref: ref, tenantId: tenantId);

  final policy = ref.read(issuePolicyEngineProvider);

  return IssueActionController(lifecycle: lifecycle, policy: policy);
});

class IssueActionController {
  final IssueLifecycleController lifecycle;
  final IssuePolicyEngine policy;

  IssueActionController({required this.lifecycle, required this.policy});

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

  Future<void> _execute(
    BuildContext context,
    IssueAction action,
    IssueRecord record,
  ) async {
    if (kDebugMode) {
      debugPrint(
        '[Action] TAP '
        '"${_labels[action]}" '
        'issue=${record.id} '
        'status=${record.status}',
      );
    }

    try {
      switch (action) {
        case IssueAction.approve:
          await lifecycle.approve(context, record);
          break;

        case IssueAction.reject:
          await lifecycle.reject(context, record);
          break;

        case IssueAction.cancel:
          await lifecycle.cancel(context, record);
          break;

        case IssueAction.issue:
          await lifecycle.markAsIssued(context, record);
          break;

        case IssueAction.receive:
          await lifecycle.markAsReceived(context, record);
          break;

        case IssueAction.dispose:
          await lifecycle.markAsDisposed(context, record);
          break;

        case IssueAction.dispense:
          await lifecycle.markAsDispensed(
            context,
            record,
            'Dispensed via UI action',
          );
          break;
      }

      if (kDebugMode) {
        debugPrint(
          '[Action] DONE '
          '"${_labels[action]}" '
          'issue=${record.id}',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[Action][ERR] '
          '"${_labels[action]}" '
          'issue=${record.id}: '
          '$e\n$st',
        );
      }

      rethrow;
    }
  }

  List<IssueActionButton> getAvailableActions({
    required AuthUser user,
    required IssueRecord record,
    required List<InventoryLocation> allStores,
  }) {
    final actions = policy.actionsFor(user: user, record: record);

    if (kDebugMode) {
      final primaryRole = staffRoleLabel(user);

      final staffRolesStr = user.staffRoles.isEmpty
          ? '-'
          : user.staffRoles.map((role) => role.name).join(', ');

      debugPrint(
        '[Actions] resolve '
        'user=${user.uid} '
        'role=$primaryRole '
        'staffRoles=[$staffRolesStr] '
        'issue=${record.id} '
        'status=${record.status} '
        'from=${record.fromStore} '
        'to=${record.toStore} '
        'stores=${allStores.length} '
        '→ [${actions.map((a) => _labels[a]).join(', ')}]',
      );
    }

    return actions.map((action) {
      return IssueActionButton(
        label: _labels[action]!,
        icon: _icons[action]!,
        color: getIssueActionColor(action),
        handler: (context) => _execute(context, action, record),
      );
    }).toList();
  }
}
