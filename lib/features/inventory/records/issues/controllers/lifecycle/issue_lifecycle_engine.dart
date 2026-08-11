// lib/features/inventory/records/issues/controllers/lifecycle/issue_lifecycle_engine.dart

import 'package:afyakit/features/inventory/records/issues/models/issue_outcome.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_record.dart';
import 'package:afyakit/features/inventory/records/issues/services/issue_service.dart';

import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/shared/types/result.dart';

class IssueLifecycleEngine {
  final String tenantId;
  final IssueService issueService;

  const IssueLifecycleEngine({
    required this.tenantId,
    required this.issueService,
  });

  Future<Result<IssueOutcome>> approve(IssueRecord record) async {
    return _run(
      operation: 'approve',
      action: () => issueService.approve(tenantId, record.id),
      successMessage: '✅ Request approved.',
    );
  }

  Future<Result<IssueOutcome>> reject(IssueRecord record) async {
    return _run(
      operation: 'reject',
      action: () => issueService.reject(tenantId, record.id),
      successMessage: '🚫 Request rejected.',
    );
  }

  Future<Result<IssueOutcome>> cancel(IssueRecord record) async {
    return _run(
      operation: 'cancel',
      action: () => issueService.cancel(tenantId, record.id),
      successMessage: '❌ Request cancelled.',
    );
  }

  Future<Result<IssueOutcome>> markAsIssued(IssueRecord record) async {
    return _run(
      operation: 'issue',
      action: () => issueService.issue(tenantId, record.id),
      successMessage: '📦 Stock issued.',
    );
  }

  Future<Result<IssueOutcome>> markAsReceived(IssueRecord record) async {
    return _run(
      operation: 'receive',
      action: () => issueService.receive(tenantId, record.id),
      successMessage: '✅ Stock received.',
    );
  }

  Future<Result<IssueOutcome>> markAsDisposed(IssueRecord record) async {
    return _run(
      operation: 'dispose',
      action: () => issueService.dispose(tenantId, record.id),
      successMessage: '🗑️ Items disposed.',
    );
  }

  Future<Result<IssueOutcome>> markAsDispensed(
    IssueRecord record,
    String reason,
  ) async {
    return _run(
      operation: 'dispense',
      action: () => issueService.dispense(tenantId, record.id, reason: reason),
      successMessage: '💊 Items dispensed.',
    );
  }

  Future<Result<IssueOutcome>> _run({
    required String operation,
    required Future<IssueRecord> Function() action,
    required String successMessage,
  }) async {
    try {
      final updated = await action();

      return Ok(IssueOutcome(updated, successMessage));
    } catch (e) {
      return Err(AppError('${operation}_failed', e.toString()));
    }
  }
}
