// lib/features/records/issues/controllers/issue_lifecycle_controller.dart

import 'package:afyakit/features/records/delivery_sessions/services/delivery_locked_exception.dart';
import 'package:afyakit/features/records/issues/controllers/engines/issue_lifecycle_engine.dart';
import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  }

  // ─────────────────────────────────────────────────────────────
  // Status Transitions (UI layer: confirmations + snacks)
  // ─────────────────────────────────────────────────────────────

  Future<void> approve(BuildContext context, IssueRecord record) async {
    if (!await _confirm('Approve this request?')) return;
    final res = await _engine.approve(record);
    if (!res.isOk) return SnackService.showError(res.error!);
    if (!context.mounted) return;
    await _applyAndToast(context, res);
  }

  Future<void> reject(BuildContext context, IssueRecord record) async {
    if (!await _confirm('Reject this request?')) return;
    final res = await _engine.reject(record);
    if (!res.isOk) return SnackService.showError(res.error!);
    if (!context.mounted) return;
    await _applyAndToast(context, res);
  }

  Future<void> cancel(BuildContext context, IssueRecord record) async {
    if (!await _confirm('Cancel this request?')) return;
    final res = await _engine.cancel(record);
    if (!res.isOk) return SnackService.showError(res.error!);
    if (!context.mounted) return;
    await _applyAndToast(context, res);
  }

  Future<void> markAsIssued(BuildContext context, IssueRecord record) async {
    if (!await _confirm('Mark as issued?')) return;
    try {
      final res = await _engine.markAsIssued(
        context,
        record,
      ); // if your engine needs ctx
      if (!res.isOk) return SnackService.showError(res.error!);
      if (!context.mounted) return;
      await _applyAndToast(context, res);
    } on DeliveryLockedException catch (e) {
      SnackService.showError(e.message);
    }
  }

  Future<void> markAsReceived(BuildContext context, IssueRecord record) async {
    if (!await _confirm('Confirm stock received?')) return;
    try {
      final res = await _engine.markAsReceived(record);
      if (!res.isOk) return SnackService.showError(res.error!);
      if (!context.mounted) return;
      await _applyAndToast(context, res);
    } on DeliveryLockedException catch (e) {
      // Usually receiving shouldn't be blocked; this is here just in case.
      SnackService.showError(e.message);
    }
  }

  Future<void> markAsDisposed(BuildContext context, IssueRecord record) async {
    if (!await _confirm('Dispose these items?')) return;
    try {
      final res = await _engine.markAsDisposed(
        context,
        record,
      ); // if your engine needs ctx
      if (!res.isOk) return SnackService.showError(res.error!);
      if (!context.mounted) return;
      await _applyAndToast(context, res);
    } on DeliveryLockedException catch (e) {
      SnackService.showError(e.message);
    }
  }

  Future<void> markAsDispensed(
    BuildContext context,
    IssueRecord record,
    String reason,
  ) async {
    if (!await _confirm('Dispense these items?')) return;
    try {
      final res = await _engine.markAsDispensed(
        context,
        record,
        reason,
      ); // if your engine needs ctx
      if (!res.isOk) return SnackService.showError(res.error!);
      if (!context.mounted) return;
      await _applyAndToast(context, res);
    } on DeliveryLockedException catch (e) {
      SnackService.showError(e.message);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Internal Utilities
  // ─────────────────────────────────────────────────────────────

  Future<void> _applyAndToast(
    BuildContext context,
    Result<IssueRecord> res,
  ) async {
    await batchService.applyStatusUpdate(
      context,
      res.value!,
      res.message ?? '✅ Done.',
    );
  }

  Future<bool> _confirm(String message) async {
    return await DialogService.confirm(title: 'Confirm', content: message) ??
        false;
  }
}
