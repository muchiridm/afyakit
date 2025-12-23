// lib/core/records/issues/controllers/form/issue_form_controller.dart

import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/features/inventory/records/issues/controllers/form/issue_form_engine.dart';
import 'package:afyakit/features/inventory/records/issues/extensions/issue_type_x.dart';
import 'package:afyakit/features/inventory/records/issues/services/inventory_snapshot.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/records/issues/controllers/form/issue_form_state.dart';
import 'package:afyakit/features/inventory/records/issues/controllers/cart/multi_cart_controller.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_record.dart';
import 'package:afyakit/features/inventory/records/issues/services/issue_service.dart';

import 'package:afyakit/shared/notifiers/safe_state_notifier.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:uuid/uuid.dart';

final issueFormControllerProvider =
    StateNotifierProvider.autoDispose<IssueFormController, IssueFormState>(
      (ref) => IssueFormController(ref),
    );

class IssueFormController extends SafeStateNotifier<IssueFormState> {
  final Ref ref;

  /// Single stable key per screen/session to prevent dupes on double-click.
  final String _requestKey = const Uuid().v4();

  IssueFormController(this.ref) : super(IssueFormState());

  void setType(IssueType type) {
    state = state.copyWith(type: type);
    ref.read(multiCartProvider.notifier).setTypeForAll(type);
  }

  void setRequestDate(DateTime date) {
    state = state.copyWith(requestDate: date);
    ref.read(multiCartProvider.notifier).setDateForAll(date);
  }

  void setDestination(String? destination) {
    state = state.copyWith(toStore: destination);
    ref.read(multiCartProvider.notifier).setDestinationForAll(destination);
  }

  void setNote(String note) {
    state = state.copyWith(note: note);
    ref.read(multiCartProvider.notifier).setNoteForAll(note);
  }

  void selectIssue(IssueRecord record) {
    state = state.copyWith(selectedIssue: record);
  }

  // ────────────────────────────────────────────
  // Submit multi-cart → one issue per store
  // ────────────────────────────────────────────

  Future<void> submit(BuildContext context) async {
    final cartState = ref.read(multiCartProvider);
    final user = ref.read(currentUserProvider).asData?.value;

    if (user == null) {
      SnackService.showError('User not loaded');
      return;
    }

    final hasAnyItems = cartState.cartsByStore.values.any((c) => c.isNotEmpty);
    if (!hasAnyItems) {
      SnackService.showError('Nothing to submit');
      return;
    }

    state = state.copyWith(isSubmitting: true);

    try {
      // Snapshot of inventory at submit time
      final snap = readInventorySnapshot(ref);

      // Use shared engine (which already knows the tenant/service)
      final engine = ref.read(issueFormEngineProvider);

      final result = await engine.submitMultiCart(
        requester: user, // 👈 full AuthUser
        cartState: cartState,
        batches: snap.batches,
        meds: snap.meds,
        cons: snap.cons,
        equips: snap.equips,
        requestKeyBase: _requestKey, // 👈 stable, per-screen key
      );

      if (result.allSuccess) {
        ref.read(multiCartProvider.notifier).clearAll();
        SnackService.showSuccess('✅ All issue requests submitted!');
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } else {
        SnackService.showError('⚠️ Some submissions failed.');
        if (result.storeErrors.isNotEmpty) {
          // Show the first error detail as a follow-up
          SnackService.showError(result.storeErrors.values.first);
        }
      }
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  // ────────────────────────────────────────────
  // Legacy list loader (dashboard/history)
  // ────────────────────────────────────────────

  Future<void> loadIssuedRecords() async {
    if (!mounted) return;

    final tenantId = ref.read(tenantSlugProvider);
    final service = IssueService(tenantId);

    try {
      final records = await service.getAllIssues();
      if (!mounted) return;
      state = state.copyWith(issuedRecords: records);
    } catch (e, stack) {
      debugPrint('❌ Failed to load issued records: $e');
      debugPrint('🧱 $stack');
      SnackService.showError('Failed to load issued records');
    }
  }
}
