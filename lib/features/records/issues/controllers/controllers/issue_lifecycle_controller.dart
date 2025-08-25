// lib/features/records/issues/controllers/issue_lifecycle_controller.dart

import 'package:afyakit/features/records/delivery_sessions/utils/delivery_locked_exception.dart';
import 'package:afyakit/features/records/issues/controllers/engines/issue_lifecycle_engine.dart';
import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'package:afyakit/features/records/issues/models/issue_record.dart';
import 'package:afyakit/features/records/issues/services/issue_service.dart';
import 'package:afyakit/features/records/issues/services/issue_batch_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';

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
    _engine = IssueLifecycleEngine(
      issueService: service,
      batchService: batchService,
      currentUserUid: currentUser.uid,
      currentUserName: currentUser.displayName,
      currentUserRole: currentUser.role.name,
    );
    if (kDebugMode) {
      debugPrint(
        '[Lifecycle] init tenant=$tenantId user=${currentUser.uid} '
        'role=${currentUser.role.name}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Status Transitions (UI layer: confirmations + snacks)
  // ─────────────────────────────────────────────────────────────

  Future<void> approve(BuildContext context, IssueRecord record) async {
    debugPrint(
      '[Lifecycle] approve ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Approve this request?')) {
      debugPrint('[Lifecycle] approve CANCELLED by user');
      return;
    }
    final res = await _engine.approve(record);
    if (!res.isOk) {
      debugPrint('[Lifecycle][ERR] approve: ${res.error}');
      return SnackService.showError(res.error!);
    }
    debugPrint('[Lifecycle] approve OK -> newStatus=${res.value!.status}');
    if (!context.mounted) return;
    await _applyAndToast(context, res);
  }

  Future<void> reject(BuildContext context, IssueRecord record) async {
    debugPrint(
      '[Lifecycle] reject ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Reject this request?')) {
      debugPrint('[Lifecycle] reject CANCELLED by user');
      return;
    }
    final res = await _engine.reject(record);
    if (!res.isOk) {
      debugPrint('[Lifecycle][ERR] reject: ${res.error}');
      return SnackService.showError(res.error!);
    }
    debugPrint('[Lifecycle] reject OK -> newStatus=${res.value!.status}');
    if (!context.mounted) return;
    await _applyAndToast(context, res);
  }

  Future<void> cancel(BuildContext context, IssueRecord record) async {
    debugPrint(
      '[Lifecycle] cancel ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Cancel this request?')) {
      debugPrint('[Lifecycle] cancel CANCELLED by user');
      return;
    }
    final res = await _engine.cancel(record);
    if (!res.isOk) {
      debugPrint('[Lifecycle][ERR] cancel: ${res.error}');
      return SnackService.showError(res.error!);
    }
    debugPrint('[Lifecycle] cancel OK -> newStatus=${res.value!.status}');
    if (!context.mounted) return;
    await _applyAndToast(context, res);
  }

  Future<void> markAsIssued(BuildContext context, IssueRecord record) async {
    debugPrint(
      '[Lifecycle] issue ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Mark as issued?')) {
      debugPrint('[Lifecycle] issue CANCELLED by user');
      return;
    }
    try {
      final res = await _engine.markAsIssued(context, record);
      if (!res.isOk) {
        debugPrint('[Lifecycle][ERR] issue: ${res.error}');
        return SnackService.showError(res.error!);
      }
      debugPrint('[Lifecycle] issue OK -> newStatus=${res.value!.status}');
      if (!context.mounted) return;
      await _applyAndToast(context, res);
    } on DeliveryLockedException catch (e) {
      debugPrint('[Lifecycle][LOCK] issue: ${e.message}');
      SnackService.showError(e.message);
    } catch (e, st) {
      debugPrint('[Lifecycle][ERR] issue EXC: $e\n$st');
      SnackService.showError('$e');
    }
  }

  Future<void> markAsReceived(BuildContext context, IssueRecord record) async {
    debugPrint(
      '[Lifecycle] receive ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Confirm stock received?')) {
      debugPrint('[Lifecycle] receive CANCELLED by user');
      return;
    }
    try {
      final res = await _engine.markAsReceived(record);
      if (!res.isOk) {
        debugPrint('[Lifecycle][ERR] receive: ${res.error}');
        return SnackService.showError(res.error!);
      }
      debugPrint('[Lifecycle] receive OK -> newStatus=${res.value!.status}');
      if (!context.mounted) return;
      await _applyAndToast(context, res);
    } on DeliveryLockedException catch (e) {
      debugPrint('[Lifecycle][LOCK] receive: ${e.message}');
      SnackService.showError(e.message);
    } catch (e, st) {
      debugPrint('[Lifecycle][ERR] receive EXC: $e\n$st');
      SnackService.showError('$e');
    }
  }

  Future<void> markAsDisposed(BuildContext context, IssueRecord record) async {
    debugPrint(
      '[Lifecycle] dispose ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Dispose these items?')) {
      debugPrint('[Lifecycle] dispose CANCELLED by user');
      return;
    }
    try {
      final res = await _engine.markAsDisposed(context, record);
      if (!res.isOk) {
        debugPrint('[Lifecycle][ERR] dispose: ${res.error}');
        return SnackService.showError(res.error!);
      }
      debugPrint('[Lifecycle] dispose OK -> newStatus=${res.value!.status}');
      if (!context.mounted) return;
      await _applyAndToast(context, res);
    } on DeliveryLockedException catch (e) {
      debugPrint('[Lifecycle][LOCK] dispose: ${e.message}');
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
    debugPrint(
      '[Lifecycle] dispense ENTER id=${record.id} status=${record.status}',
    );
    if (!await _confirm(context, 'Dispense these items?')) {
      debugPrint('[Lifecycle] dispense CANCELLED by user');
      return;
    }
    try {
      final res = await _engine.markAsDispensed(context, record, reason);
      if (!res.isOk) {
        debugPrint('[Lifecycle][ERR] dispense: ${res.error}');
        return SnackService.showError(res.error!);
      }
      debugPrint('[Lifecycle] dispense OK -> newStatus=${res.value!.status}');
      if (!context.mounted) return;
      await _applyAndToast(context, res);
    } on DeliveryLockedException catch (e) {
      debugPrint('[Lifecycle][LOCK] dispense: ${e.message}');
      SnackService.showError(e.message);
    } catch (e, st) {
      debugPrint('[Lifecycle][ERR] dispense EXC: $e\n$st');
      SnackService.showError('$e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Internal Utilities
  // ─────────────────────────────────────────────────────────────

  Future<void> _applyAndToast(
    BuildContext context,
    Result<IssueRecord> res,
  ) async {
    final rec = res.value!;
    final path = 'tenants/$tenantId/issues/${rec.id}';
    debugPrint('[Write] apply id=${rec.id} newStatus=${rec.status} path=$path');
    try {
      await batchService.applyStatusUpdate(
        context,
        rec,
        res.message ?? '✅ Done.',
      );
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

    // Fallback local dialog (never silently returns null)
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
