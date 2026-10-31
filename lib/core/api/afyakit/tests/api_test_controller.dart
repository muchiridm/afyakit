// lib/core/api/afyakit/tests/api_test_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'api_test_service.dart';

class ApiTestState {
  const ApiTestState({
    this.itemIdInput = '',
    this.batchIdInput = '',
    this.loading = false,
    this.logLines = const <String>[],
  });

  final String itemIdInput;
  final String batchIdInput;
  final bool loading;
  final List<String> logLines;

  ApiTestState copyWith({
    String? itemIdInput,
    String? batchIdInput,
    bool? loading,
    List<String>? logLines,
  }) {
    return ApiTestState(
      itemIdInput: itemIdInput ?? this.itemIdInput,
      batchIdInput: batchIdInput ?? this.batchIdInput,
      loading: loading ?? this.loading,
      logLines: logLines ?? this.logLines,
    );
  }
}

// ─────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────

final apiTestServiceProvider = Provider<ApiTestService>((ref) {
  final client = ref.watch(afyakitClientFutureProvider).requireValue;

  return ApiTestService(client);
});

final apiTestControllerProvider =
    StateNotifierProvider<ApiTestController, ApiTestState>(
      (ref) => ApiTestController(ref.watch(apiTestServiceProvider)),
    );

// ─────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────

class ApiTestController extends StateNotifier<ApiTestState> {
  ApiTestController(this._service) : super(const ApiTestState());

  final ApiTestService _service;

  void setItemId(String value) {
    state = state.copyWith(itemIdInput: value);
  }

  void setBatchId(String value) {
    state = state.copyWith(batchIdInput: value);
  }

  void _start() {
    state = state.copyWith(loading: true, logLines: <String>[]);
  }

  void _stop() {
    if (!mounted) return;
    state = state.copyWith(loading: false);
  }

  void _log(String message) {
    if (!mounted) return;

    state = state.copyWith(logLines: [...state.logLines, message]);
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (state.loading) return;

    _start();

    try {
      await operation();
    } catch (error) {
      _log('❌ $error');
    } finally {
      _stop();
    }
  }

  // ─────────────────────────────────────────────
  // Connectivity and item lookup
  // ─────────────────────────────────────────────

  Future<void> runTests() => _run(() async {
    try {
      final response = await _service.ping();

      _log('✅ GET /ping → ${response.statusCode}');
      _log(_service.prettyJson(response.data));
    } catch (error) {
      _log('❌ Ping failed: $error');
    }

    final itemId = state.itemIdInput.trim();

    if (itemId.isEmpty) return;

    try {
      final response = await _service.getItemById(itemId);

      _log(
        '✅ GET /inventory/items/$itemId '
        '→ ${response.statusCode}',
      );

      _log(_service.prettyJson(response.data));
    } catch (error) {
      _log('❌ Item lookup failed: $error');
    }
  });

  // ─────────────────────────────────────────────
  // Item lookup
  // ─────────────────────────────────────────────

  Future<void> searchItemAcrossTypes() => searchItemById();

  Future<void> searchItemById() => _run(() async {
    final itemId = state.itemIdInput.trim();

    if (itemId.isEmpty) {
      _log('Enter an Item ID first.');
      return;
    }

    final response = await _service.getItemById(itemId);

    _log('✅ Item found: $itemId');
    _log('HTTP ${response.statusCode}');
    _log(_service.prettyJson(response.data));
  });

  // ─────────────────────────────────────────────
  // Batch lookup
  // ─────────────────────────────────────────────

  Future<void> searchBatchId() => _run(() async {
    final batchId = state.batchIdInput.trim();

    if (batchId.isEmpty) {
      _log('Enter a Batch ID first.');
      return;
    }

    final response = await _service.getBatchById(batchId);

    _log('✅ Batch found: $batchId');
    _log('HTTP ${response.statusCode}');
    _log(_service.prettyJson(response.data));
  });

  // ─────────────────────────────────────────────
  // Inventory diagnostics
  // ─────────────────────────────────────────────

  Future<void> listItemTypes() => _run(() async {
    final response = await _service.listItemTypes();

    _log('GET /inventory/items/types');
    _log('HTTP ${response.statusCode}');
    _log(_service.prettyJson(response.data));
  });

  Future<void> listStores() => _run(() async {
    final response = await _service.listLocations(locationType: 'store');

    _log('GET /inventory/locations?location_type=store');
    _log('HTTP ${response.statusCode}');
    _log(_service.prettyJson(response.data));
  });

  Future<void> listInventoryBatches() => _run(() async {
    final response = await _service.listBatches();

    _log('GET /inventory/batches');
    _log('HTTP ${response.statusCode}');
    _log(_service.prettyJson(response.data));
  });
}
