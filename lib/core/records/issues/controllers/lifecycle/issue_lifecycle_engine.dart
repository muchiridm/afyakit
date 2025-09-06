import 'package:flutter/material.dart';

import 'package:afyakit/core/records/issues/extensions/issue_status_x.dart';
import 'package:afyakit/core/records/issues/extensions/issue_type_x.dart';
import 'package:afyakit/core/records/issues/models/issue_record.dart';
import 'package:afyakit/core/records/issues/services/issue_service.dart';
import 'package:afyakit/core/records/issues/services/issue_batch_service.dart';
import 'package:afyakit/core/records/issues/services/issue_validator.dart';
import 'package:afyakit/core/records/issues/models/audit_actor.dart';
import 'package:afyakit/core/records/issues/models/issue_outcome.dart';

import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';

/// Business logic for Issue lifecycle transitions.
class IssueLifecycleEngine {
  final IssueService issueService;
  final IssueBatchService batchService;

  /// Snapshot of the acting user (uid, resolved name, role) at action time.
  AuditActor actor;

  IssueLifecycleEngine({
    required this.issueService,
    required this.batchService,
    required this.actor,
  });

  /// Allow controller to refresh the actor just-in-time.
  void setActor(AuditActor a) => actor = a;

  // ── guards ───────────────────────────────────────────────────
  Result<void> _requireStatus(
    IssueRecord r,
    IssueStatus required,
    String action,
  ) {
    if (r.statusEnum != required) {
      return Err(
        AppError('invalid_status', 'Must be ${required.label} to $action.'),
      );
    }
    return const Ok(null);
  }

  String get _actorName =>
      actor.name.trim().isNotEmpty ? actor.name : actor.uid;

  // ── transitions ──────────────────────────────────────────────
  Future<Result<IssueOutcome>> approve(IssueRecord r) async {
    final guard = _requireStatus(r, IssueStatus.pending, 'approve');
    if (guard.isErr) return Err(guard.errorOrNull()!);

    final updated = r.copyWith(
      status: IssueStatus.approved.name,
      dateApproved: DateTime.now(),
      approvedByUid: actor.uid,
    );
    return Ok(IssueOutcome(updated, '✅ Request approved.'));
  }

  Future<Result<IssueOutcome>> reject(IssueRecord r) async {
    final guard = _requireStatus(r, IssueStatus.pending, 'reject');
    if (guard.isErr) return Err(guard.errorOrNull()!);

    final updated = r.copyWith(
      status: IssueStatus.rejected.name,
      dateApproved: DateTime.now(),
      approvedByUid: actor.uid,
    );
    return Ok(IssueOutcome(updated, '🚫 Request rejected.'));
  }

  Future<Result<IssueOutcome>> cancel(IssueRecord r) async {
    if (r.statusEnum == IssueStatus.cancelled) {
      return Err(AppError('already_cancelled', '⚠️ Already cancelled.'));
    }
    final updated = r.copyWith(
      status: IssueStatus.cancelled.name,
      actionedByUid: actor.uid,
      actionedByName: _actorName,
      actionedByRole: actor.role,
    );
    return Ok(IssueOutcome(updated, '❌ Request cancelled.'));
  }

  Future<Result<IssueOutcome>> markAsIssued(
    BuildContext context,
    IssueRecord r,
  ) async {
    final guard = _requireStatus(r, IssueStatus.approved, 'issue');
    if (guard.isErr) return Err(guard.errorOrNull()!);

    final entries = await issueService.getEntriesForIssue(r.id);
    final validation = IssueValidator.validateSubmission(
      record: r,
      entries: entries,
    );
    if (!validation.isValid) {
      return Err(
        AppError(
          'invalid_issue',
          validation.errorMessage ?? '❌ Invalid issue.',
        ),
      );
    }

    for (final entry in entries) {
      if (entry.batchId == null) continue;
      await batchService.adjustBatchQuantity(
        type: r.type,
        fromStore: r.fromStore,
        toStore: r.toStore,
        batchId: entry.batchId!,
        itemId: entry.itemId,
        quantity: entry.quantity,
        context: context,
        metadata: {'issueId': r.id, 'entryId': entry.id},
      );
    }

    final updated = r.copyWith(
      status: IssueStatus.issued.name,
      dateIssuedOrReceived: DateTime.now(),
      actionedByUid: actor.uid,
      actionedByName: _actorName,
      actionedByRole: actor.role,
    );
    return Ok(IssueOutcome(updated, '📦 Stock issued.'));
  }

  Future<Result<IssueOutcome>> markAsReceived(IssueRecord r) async {
    final guard = _requireStatus(r, IssueStatus.issued, 'receive');
    if (guard.isErr) return Err(guard.errorOrNull()!);

    final docs = await batchService.getUnreceivedTransitDocs(r.id);
    if (docs.isEmpty) {
      return Err(
        AppError('no_transit_docs', '❌ No pending transit records found.'),
      );
    }

    for (final doc in docs) {
      await batchService.receiveTransit(doc.id, doc.data());
    }

    final updated = r.copyWith(
      status: IssueStatus.received.name,
      dateIssuedOrReceived: DateTime.now(),
      actionedByUid: actor.uid,
      actionedByName: _actorName,
      actionedByRole: actor.role,
    );
    return Ok(IssueOutcome(updated, '✅ Stock received.'));
  }

  Future<Result<IssueOutcome>> markAsDisposed(
    BuildContext context,
    IssueRecord r,
  ) async {
    final guard = _requireStatus(r, IssueStatus.approved, 'dispose');
    if (guard.isErr) return Err(guard.errorOrNull()!);
    if (r.type != IssueType.dispose) {
      return Err(AppError('not_disposal', '⚠️ Not a disposal request.'));
    }

    final entries = await issueService.getEntriesForIssue(r.id);
    if (entries.isEmpty) {
      return Err(AppError('no_items', '⚠️ No items to dispose.'));
    }

    for (final entry in entries) {
      if (entry.batchId == null) continue;
      await batchService.adjustBatchQuantity(
        type: IssueType.dispose,
        fromStore: r.fromStore,
        batchId: entry.batchId!,
        itemId: entry.itemId,
        quantity: entry.quantity,
        context: context,
        metadata: {'reason': 'Disposed via issue ${r.id}'},
      );
    }

    final updated = r.copyWith(
      status: IssueStatus.disposed.name,
      dateIssuedOrReceived: DateTime.now(),
      actionedByUid: actor.uid,
      actionedByName: _actorName,
      actionedByRole: actor.role,
    );
    return Ok(IssueOutcome(updated, '🗑️ Items disposed.'));
  }

  Future<Result<IssueOutcome>> markAsDispensed(
    BuildContext context,
    IssueRecord r,
    String reason,
  ) async {
    final guard = _requireStatus(r, IssueStatus.approved, 'dispense');
    if (guard.isErr) return Err(guard.errorOrNull()!);
    if (r.type != IssueType.dispense) {
      return Err(AppError('not_dispense', '⚠️ Not a dispensing request.'));
    }

    final entries = await issueService.getEntriesForIssue(r.id);
    if (entries.isEmpty) {
      return Err(AppError('no_items', '⚠️ No items to dispense.'));
    }

    for (final entry in entries) {
      if (entry.batchId == null) continue;
      await batchService.adjustBatchQuantity(
        type: IssueType.dispense,
        fromStore: r.fromStore,
        batchId: entry.batchId!,
        itemId: entry.itemId,
        quantity: entry.quantity,
        context: context,
        metadata: {'reason': reason},
      );
    }

    final updated = r.copyWith(
      status: IssueStatus.dispensed.name,
      dateIssuedOrReceived: DateTime.now(),
      actionedByUid: actor.uid,
      actionedByName: _actorName,
      actionedByRole: actor.role,
    );
    return Ok(IssueOutcome(updated, '💊 Items dispensed.'));
  }
}
