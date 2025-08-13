// lib/features/records/issues/engines/issue_engine.dart
import 'package:flutter/material.dart';

import 'package:afyakit/features/records/issues/models/enums/issue_status_enum.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_status_x.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_type_enum.dart';
import 'package:afyakit/features/records/issues/models/issue_record.dart';
import 'package:afyakit/features/records/issues/services/issue_service.dart';
import 'package:afyakit/features/records/issues/services/issue_batch_service.dart';
import 'package:afyakit/features/records/issues/services/issue_validator.dart';

/// Lightweight result type (no dartz dependency)
class Result<T> {
  final T? value;
  final String? error;
  final String? message;

  const Result._({this.value, this.error, this.message});

  static Result<T> ok<T>(T v, {String? message}) =>
      Result._(value: v, message: message);
  static Result<T> fail<T>(String e) => Result._(error: e);

  bool get isOk => error == null;
}

/// Business logic for Issue lifecycle transitions.
/// NOTE: This engine accepts BuildContext so it can call IssueBatchService.adjustBatchQuantity,
/// which requires `context`. If you later want a pure engine, we can return a plan of adjustments
/// and let the controller apply them.
class IssueLifecycleEngine {
  final IssueService issueService;
  final IssueBatchService batchService;

  // current user metadata for audit fields
  final String currentUserUid;
  final String currentUserName;
  final String currentUserRole;

  IssueLifecycleEngine({
    required this.issueService,
    required this.batchService,
    required this.currentUserUid,
    required this.currentUserName,
    required this.currentUserRole,
  });

  Result<IssueRecord> _requireStatus(
    IssueRecord r,
    IssueStatus required,
    String action,
  ) {
    if (r.statusEnum != required) {
      return Result.fail('Must be ${required.label} to $action.');
    }
    return Result.ok(r);
  }

  Future<Result<IssueRecord>> approve(IssueRecord r) async {
    final guard = _requireStatus(r, IssueStatus.pending, 'approve');
    if (!guard.isOk) return Result.fail(guard.error!);

    final updated = r.copyWith(
      status: IssueStatus.approved.name,
      dateApproved: DateTime.now(),
      approvedByUid: currentUserUid,
    );
    // Persistence applied by caller.
    return Result.ok(updated, message: '✅ Request approved.');
  }

  Future<Result<IssueRecord>> reject(IssueRecord r) async {
    final guard = _requireStatus(r, IssueStatus.pending, 'reject');
    if (!guard.isOk) return Result.fail(guard.error!);

    final updated = r.copyWith(
      status: IssueStatus.rejected.name,
      dateApproved: DateTime.now(),
      approvedByUid: currentUserUid,
    );
    return Result.ok(updated, message: '🚫 Request rejected.');
  }

  Future<Result<IssueRecord>> cancel(IssueRecord r) async {
    if (r.statusEnum == IssueStatus.cancelled) {
      return Result.fail('⚠️ Already cancelled.');
    }
    final updated = r.copyWith(
      status: IssueStatus.cancelled.name,
      actionedByUid: currentUserUid,
      actionedByName: currentUserName,
      actionedByRole: currentUserRole,
    );
    return Result.ok(updated, message: '❌ Request cancelled.');
  }

  Future<Result<IssueRecord>> markAsIssued(
    BuildContext context,
    IssueRecord r,
  ) async {
    final guard = _requireStatus(r, IssueStatus.approved, 'issue');
    if (!guard.isOk) return Result.fail(guard.error!);

    final entries = await issueService.getEntriesForIssue(r.id);
    final validation = IssueValidator.validateSubmission(
      record: r,
      entries: entries,
    );
    if (!validation.isValid) {
      return Result.fail(validation.errorMessage ?? '❌ Invalid issue.');
    }

    // Deduct from source (or create transit) via batchService
    for (final entry in entries) {
      if (entry.batchId == null) continue;
      await batchService.adjustBatchQuantity(
        type: r.type,
        fromStore: r.fromStore,
        toStore: r.toStore,
        batchId: entry.batchId!,
        itemId: entry.itemId,
        quantity: entry.quantity,
        context: context, // ← required by IssueBatchService
        metadata: {'issueId': r.id, 'entryId': entry.id},
      );
    }

    final updated = r.copyWith(
      status: IssueStatus.issued.name,
      dateIssuedOrReceived: DateTime.now(),
      actionedByUid: currentUserUid,
      actionedByName: currentUserName,
      actionedByRole: currentUserRole,
    );
    return Result.ok(updated, message: '📦 Stock issued.');
  }

  Future<Result<IssueRecord>> markAsReceived(IssueRecord r) async {
    final guard = _requireStatus(r, IssueStatus.issued, 'receive');
    if (!guard.isOk) return Result.fail(guard.error!);

    final docs = await batchService.getUnreceivedTransitDocs(r.id);
    if (docs.isEmpty) return Result.fail('❌ No pending transit records found.');

    for (final doc in docs) {
      await batchService.receiveTransit(doc.id, doc.data());
    }

    final updated = r.copyWith(
      status: IssueStatus.received.name,
      dateIssuedOrReceived: DateTime.now(),
      actionedByUid: currentUserUid,
      actionedByName: currentUserName,
      actionedByRole: currentUserRole,
    );
    return Result.ok(updated, message: '✅ Stock received.');
  }

  Future<Result<IssueRecord>> markAsDisposed(
    BuildContext context,
    IssueRecord r,
  ) async {
    final guard = _requireStatus(r, IssueStatus.approved, 'dispose');
    if (!guard.isOk) return Result.fail(guard.error!);
    if (r.type != IssueType.dispose) {
      return Result.fail('⚠️ Not a disposal request.');
    }

    final entries = await issueService.getEntriesForIssue(r.id);
    if (entries.isEmpty) return Result.fail('⚠️ No items to dispose.');

    for (final entry in entries) {
      if (entry.batchId == null) continue;
      await batchService.adjustBatchQuantity(
        type: IssueType.dispose,
        fromStore: r.fromStore,
        batchId: entry.batchId!,
        itemId: entry.itemId,
        quantity: entry.quantity,
        context: context, // ← required by IssueBatchService
        metadata: {'reason': 'Disposed via issue ${r.id}'},
      );
    }

    final updated = r.copyWith(
      status: IssueStatus.disposed.name,
      dateIssuedOrReceived: DateTime.now(),
      actionedByUid: currentUserUid,
      actionedByName: currentUserName,
      actionedByRole: currentUserRole,
    );
    return Result.ok(updated, message: '🗑️ Items disposed.');
  }

  Future<Result<IssueRecord>> markAsDispensed(
    BuildContext context,
    IssueRecord r,
    String reason,
  ) async {
    final guard = _requireStatus(r, IssueStatus.approved, 'dispense');
    if (!guard.isOk) return Result.fail(guard.error!);
    if (r.type != IssueType.dispense) {
      return Result.fail('⚠️ Not a dispensing request.');
    }

    final entries = await issueService.getEntriesForIssue(r.id);
    if (entries.isEmpty) return Result.fail('⚠️ No items to dispense.');

    for (final entry in entries) {
      if (entry.batchId == null) continue;
      await batchService.adjustBatchQuantity(
        type: IssueType.dispense,
        fromStore: r.fromStore,
        batchId: entry.batchId!,
        itemId: entry.itemId,
        quantity: entry.quantity,
        context: context, // ← required by IssueBatchService
        metadata: {'reason': reason},
      );
    }

    final updated = r.copyWith(
      status: IssueStatus.dispensed.name,
      dateIssuedOrReceived: DateTime.now(),
      actionedByUid: currentUserUid,
      actionedByName: currentUserName,
      actionedByRole: currentUserRole,
    );
    return Result.ok(updated, message: '💊 Items dispensed.');
  }
}
