// lib/features/inventory/records/issues/controllers/lifecycle/issue_lifecycle_controller.dart

import 'package:afyakit/features/inventory/records/issues/controllers/lifecycle/issue_lifecycle_engine.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_outcome.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_record.dart';
import 'package:afyakit/features/inventory/records/issues/services/issue_service.dart';

import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/types/result.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IssueLifecycleController {
  final Ref ref;
  final String tenantId;

  late final IssueLifecycleEngine _engine;

  IssueLifecycleController({required this.ref, required this.tenantId}) {
    final service = ref.read(issueServiceProvider);

    _engine = IssueLifecycleEngine(tenantId: tenantId, issueService: service);
  }

  // ─────────────────────────────────────────────
  // Lifecycle actions
  // ─────────────────────────────────────────────

  Future<void> approve(BuildContext context, IssueRecord record) async {
    if (!await _confirm(context, 'Approve this request?')) {
      return;
    }

    final result = await _engine.approve(record);

    await _handleResult(context, result);
  }

  Future<void> reject(BuildContext context, IssueRecord record) async {
    if (!await _confirm(context, 'Reject this request?')) {
      return;
    }

    final result = await _engine.reject(record);

    await _handleResult(context, result);
  }

  Future<void> cancel(BuildContext context, IssueRecord record) async {
    if (!await _confirm(context, 'Cancel this request?')) {
      return;
    }

    final result = await _engine.cancel(record);

    await _handleResult(context, result);
  }

  Future<void> markAsIssued(BuildContext context, IssueRecord record) async {
    if (!await _confirm(context, 'Mark as issued?')) {
      return;
    }

    final result = await _engine.markAsIssued(record);

    await _handleResult(context, result);
  }

  Future<void> markAsReceived(BuildContext context, IssueRecord record) async {
    if (!await _confirm(context, 'Confirm stock received?')) {
      return;
    }

    final result = await _engine.markAsReceived(record);

    await _handleResult(context, result);
  }

  Future<void> markAsDisposed(BuildContext context, IssueRecord record) async {
    if (!await _confirm(context, 'Dispose these items?')) {
      return;
    }

    final result = await _engine.markAsDisposed(record);

    await _handleResult(context, result);
  }

  Future<void> markAsDispensed(
    BuildContext context,
    IssueRecord record,
    String reason,
  ) async {
    if (!await _confirm(context, 'Dispense these items?')) {
      return;
    }

    final result = await _engine.markAsDispensed(record, reason);

    await _handleResult(context, result);
  }

  // ─────────────────────────────────────────────
  // Result handling
  // ─────────────────────────────────────────────

  Future<void> _handleResult(
    BuildContext context,
    Result<IssueOutcome> result,
  ) async {
    await result.fold<Future<void>>(
      ok: (outcome) async {
        SnackService.showSuccess(outcome.message);

        final details = outcome.details?.trim();

        if (details != null && details.isNotEmpty) {
          SnackService.showError(details);
        }
      },
      err: (error) async {
        debugPrint(
          '[Lifecycle][ERR] '
          '${error.code}: ${error.message}',
        );

        SnackService.showError(error.message);
      },
    );
  }

  // ─────────────────────────────────────────────
  // Confirmation
  // ─────────────────────────────────────────────

  Future<bool> _confirm(BuildContext context, String message) async {
    debugPrint('[Confirm] "$message"');

    try {
      final confirmed = await DialogService.confirm(
        title: 'Confirm',
        content: message,
      );

      debugPrint('[Confirm] result=$confirmed (DialogService)');

      return confirmed;
    } catch (e) {
      debugPrint('[Confirm][WARN] DialogService failed: $e');
    }

    final result = await showDialog<bool>(
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

    return result ?? false;
  }
}
