// lib/features/inventory/records/issues/controllers/form/issue_form_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:afyakit/features/inventory/records/cart/controllers/multi_cart_controller.dart';

import 'package:afyakit/features/inventory/records/issues/controllers/form/issue_form_engine.dart';

import 'package:afyakit/features/inventory/records/issues/controllers/form/issue_inventory_snapshot.dart';
import 'package:afyakit/features/inventory/records/issues/extensions/issue_type_x.dart';

import 'package:afyakit/shared/notifiers/safe_state_notifier.dart';
import 'package:afyakit/shared/services/snack_service.dart';

final issueFormControllerProvider =
    StateNotifierProvider.autoDispose<IssueFormController, IssueFormState>(
      (ref) => IssueFormController(ref),
    );

// lib/features/inventory/records/issues/controllers/form/issue_form_state.dart

class IssueFormState {
  final IssueType type;
  final DateTime requestDate;

  final String? fromStore;
  final String? toStore;
  final String note;
  final bool isSubmitting;

  IssueFormState({
    this.type = IssueType.dispense,
    DateTime? requestDate,
    this.fromStore,
    this.toStore,
    this.note = '',
    this.isSubmitting = false,
  }) : requestDate = requestDate ?? DateTime.now();

  IssueFormState copyWith({
    IssueType? type,
    DateTime? requestDate,
    String? fromStore,
    String? toStore,
    String? note,
    bool? isSubmitting,
  }) {
    return IssueFormState(
      type: type ?? this.type,
      requestDate: requestDate ?? this.requestDate,
      fromStore: fromStore ?? this.fromStore,
      toStore: toStore ?? this.toStore,
      note: note ?? this.note,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class IssueFormController extends SafeStateNotifier<IssueFormState> {
  IssueFormController(this.ref) : super(IssueFormState());

  final Ref ref;

  /// Stable idempotency key for this form instance.
  ///
  /// IssueFormEngine combines this with the source store ID so each
  /// store submission has a stable request key across retries.
  final String _requestKey = const Uuid().v4();

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

  // ────────────────────────────────────────────
  // Submit multi-cart → backend API
  // ────────────────────────────────────────────

  Future<void> submit(BuildContext context) async {
    final cartState = ref.read(multiCartProvider);

    final hasAnyItems = cartState.cartsByStore.values.any(
      (cart) => cart.isNotEmpty,
    );

    if (!hasAnyItems) {
      SnackService.showError('Nothing to submit');
      return;
    }

    state = state.copyWith(isSubmitting: true);

    try {
      final snapshot = readInventorySnapshot(ref);
      final engine = ref.read(issueFormEngineProvider);

      final result = await engine.submitMultiCart(
        cartState: cartState,
        batches: snapshot.batches,
        meds: snapshot.meds,
        cons: snapshot.cons,
        equips: snapshot.equips,
        requestKeyBase: _requestKey,
      );

      if (!mounted) return;

      if (result.allSuccess) {
        ref.read(multiCartProvider.notifier).clearAll();

        SnackService.showSuccess('✅ All issue requests submitted!');

        if (context.mounted) {
          Navigator.of(context).pop();
        }

        return;
      }

      SnackService.showError('⚠️ Some submissions failed.');

      if (result.storeErrors.isNotEmpty) {
        SnackService.showError(result.storeErrors.values.first);
      }
    } catch (e, st) {
      debugPrint('❌ Issue submission failed: $e\n$st');

      SnackService.showError('Failed to submit issue request');
    } finally {
      if (mounted) {
        state = state.copyWith(isSubmitting: false);
      }
    }
  }
}
