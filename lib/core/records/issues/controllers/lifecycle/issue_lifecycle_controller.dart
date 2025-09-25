// lib/core/records/issues/controllers/lifecycle/issue_lifecycle_controller.dart

import 'package:afyakit/core/records/deliveries/utils/delivery_locked_exception.dart';
import 'package:afyakit/core/records/issues/controllers/lifecycle/issue_lifecycle_engine.dart';
import 'package:afyakit/core/records/issues/models/audit_actor.dart';
import 'package:afyakit/core/records/issues/models/issue_outcome.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/records/issues/models/issue_record.dart';
import 'package:afyakit/core/records/issues/services/issue_batch_service.dart';
import 'package:afyakit/core/records/issues/services/issue_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/types/result.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/current_user_providers.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';

class IssueLifecycleController {
  final Ref ref;
  final String tenantId;
  final AuthUser currentUser;
  final IssueService service;
  final IssueBatchService batchService;

  late final IssueLifecycleEngine _engine;

  IssueLifecycleController({
    required this.ref,
    required this.tenantId,
    required this.currentUser,
  }) : service = IssueService(tenantId),
       batchService = IssueBatchService(tenantId: tenantId, ref: ref) {
    // Seed engine with a reasonable initial actor (will be refreshed per action).
    final actorName = resolveUserDisplay(
      displayName: currentUser.displayName,
      email: currentUser.email,
      phone: currentUser.phoneNumber,
      uid: currentUser.uid,
    );
    _engine = IssueLifecycleEngine(
      issueService: service,
      batchService: batchService,
      actor: AuditActor(
        uid: currentUser.uid,
        name: actorName,
        role: currentUser.role.name,
      ),
    );

    if (kDebugMode) {
      debugPrint(
        '[Lifecycle] init tenant=$tenantId user=${currentUser.uid} '
        'role=${currentUser.role.name} actorName="$actorName"',
      );
    }
  }

  // Get the freshest actor (name: displayName → email → phone → uid)
  void _refreshActor() {
    final u = ref.read(currentUserValueProvider) ?? currentUser;
    final actorName = resolveUserDisplay(
      displayName: u.displayName,
      email: u.email,
      phone: u.phoneNumber,
      uid: u.uid,
    );
    _engine.actor = AuditActor(uid: u.uid, name: actorName, role: u.role.name);

    if (kDebugMode) {
      debugPrint(
        '[Lifecycle] actor refreshed: uid=${u.uid} name="$actorName" role=${u.role.name}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Status Transitions (UI layer: confirmations + snacks)
  // ─────────────────────────────────────────────────────────────

  Future<void> approve(BuildContext context, IssueRecord record) async {
    _refreshActor();
    debugPrint(
      '[Lifecycle] approve ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Approve this request?')) return;
    final res = await _engine.approve(record);
    res.fold(
      ok: (out) async {
        if (!context.mounted) return;
        await _applyAndToast(context, out);
      },
      err: (e) => SnackService.showError(e.message),
    );
  }

  Future<void> reject(BuildContext context, IssueRecord record) async {
    _refreshActor();
    debugPrint(
      '[Lifecycle] reject ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Reject this request?')) return;
    final res = await _engine.reject(record);
    res.fold(
      ok: (out) async {
        if (!context.mounted) return;
        await _applyAndToast(context, out);
      },
      err: (e) => SnackService.showError(e.message),
    );
  }

  Future<void> cancel(BuildContext context, IssueRecord record) async {
    _refreshActor();
    debugPrint(
      '[Lifecycle] cancel ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Cancel this request?')) return;
    final res = await _engine.cancel(record);
    res.fold(
      ok: (out) async {
        if (!context.mounted) return;
        await _applyAndToast(context, out);
      },
      err: (e) => SnackService.showError(e.message),
    );
  }

  Future<void> markAsIssued(BuildContext context, IssueRecord record) async {
    _refreshActor();
    debugPrint(
      '[Lifecycle] issue ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Mark as issued?')) return;
    try {
      final res = await _engine.markAsIssued(context, record);
      res.fold(
        ok: (out) async {
          if (!context.mounted) return;
          await _applyAndToast(context, out);
        },
        err: (e) => SnackService.showError(e.message),
      );
    } on DeliveryLockedException catch (e) {
      SnackService.showError(e.message);
    } catch (e, st) {
      debugPrint('[Lifecycle][ERR] issue EXC: $e\n$st');
      SnackService.showError('$e');
    }
  }

  Future<void> markAsReceived(BuildContext context, IssueRecord record) async {
    _refreshActor();
    debugPrint(
      '[Lifecycle] receive ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Confirm stock received?')) return;
    try {
      final res = await _engine.markAsReceived(record);
      res.fold(
        ok: (out) async {
          if (!context.mounted) return;
          await _applyAndToast(context, out);
        },
        err: (e) => SnackService.showError(e.message),
      );
    } on DeliveryLockedException catch (e) {
      SnackService.showError(e.message);
    } catch (e, st) {
      debugPrint('[Lifecycle][ERR] receive EXC: $e\n$st');
      SnackService.showError('$e');
    }
  }

  Future<void> markAsDisposed(BuildContext context, IssueRecord record) async {
    _refreshActor();
    debugPrint(
      '[Lifecycle] dispose ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Dispose these items?')) return;
    try {
      final res = await _engine.markAsDisposed(context, record);
      res.fold(
        ok: (out) async {
          if (!context.mounted) return;
          await _applyAndToast(context, out);
        },
        err: (e) => SnackService.showError(e.message),
      );
    } on DeliveryLockedException catch (e) {
      SnackService.showError(e.message);
    } catch (e, st) {
      debugPrint('[Lifecycle][ERR] dispose EXC: $e\n$st');
      SnackService.showError('$e');
    }
  }

  Future<void> markAsDispensed(
    BuildContext context,
    IssueRecord record,
    String reason,
  ) async {
    _refreshActor();
    debugPrint(
      '[Lifecycle] dispense ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Dispense these items?')) return;
    try {
      final res = await _engine.markAsDispensed(context, record, reason);
      res.fold(
        ok: (out) async {
          if (!context.mounted) return;
          await _applyAndToast(context, out);
        },
        err: (e) => SnackService.showError(e.message),
      );
    } on DeliveryLockedException catch (e) {
      SnackService.showError(e.message);
    } catch (e, st) {
      debugPrint('[Lifecycle][ERR] dispense EXC: $e\n$st');
      SnackService.showError('$e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Internal Utilities
  // ─────────────────────────────────────────────────────────────

  Future<void> _applyAndToast(BuildContext context, IssueOutcome out) async {
    final rec = out.record;
    final path = 'tenants/$tenantId/issues/${rec.id}';
    debugPrint('[Write] apply id=${rec.id} newStatus=${rec.status} path=$path');
    try {
      await batchService.applyStatusUpdate(context, rec, out.message);
      debugPrint('[Write] applied id=${rec.id} newStatus=${rec.status}');
    } catch (e, st) {
      debugPrint('[Write][ERR] id=${rec.id} -> $e\n$st');
      rethrow;
    }
  }

  Future<bool> _confirm(BuildContext context, String message) async {
    debugPrint('[Confirm] "$message"');
    try {
      final ok = await DialogService.confirm(
        title: 'Confirm',
        content: message,
      );
      debugPrint('[Confirm] result=$ok (DialogService)');
      return ok;
    } catch (e) {
      debugPrint('[Confirm][WARN] DialogService failed: $e');
    }

    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    debugPrint('[Confirm] result=${r == true} (fallback)');
    return r ?? false;
  }
}
