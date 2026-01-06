import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/records/deliveries/controllers/delivery_session_state.dart';
import 'package:afyakit/features/inventory/records/deliveries/controllers/delivery_session_engine.dart';
import 'package:afyakit/features/inventory/records/deliveries/models/delivery_review_summary.dart';

/// Controller: UI-facing façade over the engine. No direct service calls.
final deliverySessionControllerProvider =
    Provider.autoDispose<DeliverySessionController>(
      (ref) => DeliverySessionController(ref),
    );

class DeliverySessionController {
  final Ref ref;
  DeliverySessionController(this.ref);

  /// Watch current session state (for widgets).
  DeliverySessionState watchState() => ref.watch(deliverySessionEngineProvider);

  /// Read current session state once (no rebuild).
  DeliverySessionState readState() => ref.read(deliverySessionEngineProvider);

  /// Proxy to engine: ensure active session.
  Future<void> ensureActive({
    required String enteredByName,
    required String enteredByEmail,
    required String source,
    String? storeId,
  }) {
    return ref
        .read(deliverySessionEngineProvider.notifier)
        .ensureActive(
          enteredByName: enteredByName,
          enteredByEmail: enteredByEmail,
          source: source,
          storeId: storeId,
        );
  }

  /// Proxy to engine: add a source.
  Future<void> addSource(String source) =>
      ref.read(deliverySessionEngineProvider.notifier).addSource(source);

  /// Proxy to engine: review summary.
  Future<DeliveryReviewSummary?> review(WidgetRef widgetRef) =>
      ref.read(deliverySessionEngineProvider.notifier).review(widgetRef);

  /// Proxy to engine: finalize (optionally auto-restart).
  Future<bool> end({bool autoRestart = false}) => ref
      .read(deliverySessionEngineProvider.notifier)
      .end(autoRestart: autoRestart);

  /// Proxy to engine: remember last used UX prefs.
  Future<void> rememberLastUsed({String? lastStoreId, String? lastSource}) =>
      ref
          .read(deliverySessionEngineProvider.notifier)
          .rememberLastUsed(lastStoreId: lastStoreId, lastSource: lastSource);
}
