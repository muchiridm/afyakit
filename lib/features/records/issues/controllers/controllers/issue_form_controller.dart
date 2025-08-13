import 'package:afyakit/features/records/issues/controllers/engines/issue_form_engine.dart';
import 'package:afyakit/features/records/issues/services/inventory_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/records/issues/controllers/states/issue_record_state.dart';
import 'package:afyakit/features/records/issues/controllers/controllers/multi_cart_controller.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_type_enum.dart';
import 'package:afyakit/features/records/issues/models/issue_record.dart';
import 'package:afyakit/features/records/issues/services/issue_service.dart';

import 'package:afyakit/shared/notifiers/safe_state_notifier.dart';
import 'package:afyakit/shared/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/providers/users/combined_user_provider.dart';

import 'package:afyakit/shared/services/snack_service.dart';

final issueFormControllerProvider =
    StateNotifierProvider.autoDispose<IssueFormController, IssueRecordState>(
      (ref) => IssueFormController(ref),
    );

class IssueFormController extends SafeStateNotifier<IssueRecordState> {
  final Ref ref;

  IssueFormController(this.ref) : super(IssueRecordState());

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

  Future<void> submit(BuildContext context) async {
    final cartState = ref.read(multiCartProvider);
    final user = ref.read(combinedUserProvider).asData?.value;

    if (user == null) {
      SnackService.showError('User not loaded');
      return;
    }

    // Cheap fast-fail: nothing selected across all stores
    final hasAnyItems = cartState.cartsByStore.values.any((c) => c.isNotEmpty);
    if (!hasAnyItems) {
      SnackService.showError('Nothing to submit');
      return;
    }

    state = state.copyWith(isSubmitting: true);
    try {
      final snap = readInventorySnapshot(ref);

      // Engine (construct directly or via provider)
      final tenantId = ref.read(tenantIdProvider);
      final engine = IssueFormEngine(IssueService(tenantId));
      // If you expose a provider: final engine = ref.read(issueFormEngineProvider);

      final result = await engine.submitMultiCart(
        userId: user.uid,
        cartState: cartState,
        batches: snap.batches,
        meds: snap.meds,
        cons: snap.cons,
        equips: snap.equips,
      );

      if (result.allSuccess) {
        ref.read(multiCartProvider.notifier).clearAll();
        SnackService.showSuccess('✅ All issue requests submitted!');
        if (context.mounted) Navigator.of(context).pop();
      } else {
        SnackService.showError('⚠️ Some submissions failed.');
        if (result.storeErrors.isNotEmpty) {
          SnackService.showError(result.storeErrors.values.first);
        }
      }
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<void> loadIssuedRecords() async {
    if (!mounted) return;

    final tenantId = ref.read(tenantIdProvider);
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
