import 'package:afyakit/api/afyakit/providers.dart';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_test_service.dart';

/// STATE
class ApiTestState {
  final String itemIdInput;
  final String batchIdInput;
  final bool loading;
  final List<String> logLines;

  const ApiTestState({
    this.itemIdInput = '',
    this.batchIdInput = '',
    this.loading = false,
    this.logLines = const <String>[],
  });

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

/// PROVIDERS
final apiTestServiceProvider = Provider<ApiTestService>((ref) {
  final client = ref.watch(afyakitClientProvider).requireValue;
  return ApiTestService(client);
});

final apiTestControllerProvider =
    StateNotifierProvider<ApiTestController, ApiTestState>((ref) {
      final svc = ref.watch(apiTestServiceProvider);
      return ApiTestController(svc);
    });

/// CONTROLLER
class ApiTestController extends StateNotifier<ApiTestState> {
  final ApiTestService _svc;
  ApiTestController(this._svc) : super(const ApiTestState());

  void setItemId(String v) => state = state.copyWith(itemIdInput: v);
  void setBatchId(String v) => state = state.copyWith(batchIdInput: v);

  void _clearAndStart() =>
      state = state.copyWith(loading: true, logLines: <String>[]);
  void _stop() => state = state.copyWith(loading: false);
  void _log(String line) =>
      state = state.copyWith(logLines: [...state.logLines, line]);

  // ---------------- Actions ----------------

  Future<void> runTests() async {
    if (state.loading) return;
    _clearAndStart();
    try {
      final ping = await _svc.ping();
      _log('✅ /ping → ${ping.statusCode}');
      _log(_svc.prettyJson(ping.data));
    } catch (e, st) {
      _log('❌ Ping failed: $e');
      _log(st.toString());
    }

    final itemId = state.itemIdInput.trim();
    if (itemId.isNotEmpty) {
      try {
        final res = await _svc.getItemById(itemId);
        _log('📦 /inventory/$itemId → ${res.statusCode}');
        _log(_svc.prettyJson(res.data));
      } catch (e, st) {
        _log('❌ Failed to get item: $e');
        _log(st.toString());
      }
    }
    _stop();
  }

  Future<void> searchItemAcrossTypes() async {
    if (state.loading) return;
    _clearAndStart();
    final target = state.itemIdInput.trim();
    if (target.isEmpty) {
      _log('ℹ️ Enter an Item ID or docId first.');
      _stop();
      return;
    }
    try {
      for (final t in ItemTypeX.searchable) {
        try {
          final list = await _svc.listInventory(t);
          for (final it in list) {
            final matches =
                it.id == target || (it.docId != null && it.docId == target);
            if (matches) {
              _log('✅ Found in "${t.apiName}":');
              _log('- 🔑 docId: ${it.docId ?? '(unknown)'}');
              _log('- 🆔 id: ${it.id}');
              _log(
                _svc.prettyJson({
                  'id': it.id,
                  'docId': it.docId,
                  'genericName': it.genericName,
                  'brandName': it.brandName,
                  'description': it.description,
                  'itemType': it.itemType,
                }),
              );
              _stop();
              return;
            }
          }
        } catch (e, st) {
          _log('❌ Error in "${t.apiName}": $e');
          _log(st.toString());
        }
      }
      _log('🕵️ Not found in any inventory collection.');
    } finally {
      _stop();
    }
  }

  Future<void> searchBatchId() async {
    if (state.loading) return;
    _clearAndStart();
    final batchId = state.batchIdInput.trim();
    if (batchId.isEmpty) {
      _log('ℹ️ Enter a Batch ID first.');
      _stop();
      return;
    }

    try {
      final found = await _svc.searchBatchAcrossStores(batchId);
      if (found.batchJson != null) {
        _log(
          '✅ Batch found '
          '${found.storeId != null ? 'in store "${found.storeId}"' : '(store unknown)'}',
        );
        _log(_svc.prettyJson(found.batchJson));
      } else {
        _log('🕵️ Batch "$batchId" not found in any store.');
      }
    } catch (e, st) {
      _log('❌ Batch search failed: $e');
      _log(st.toString());
    } finally {
      _stop();
    }
  }
}
