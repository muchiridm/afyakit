import 'dart:async';
import 'package:afyakit/hq/catalog/medication/services/rxnorm_import_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/catalog/medication/catalog_medication.dart';
import 'package:afyakit/hq/catalog/medication/services/catalog_medication_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';

final catalogMedicationControllerProvider =
    StateNotifierProvider.autoDispose<
      CatalogMedicationController,
      CatalogMedicationState
    >((ref) => CatalogMedicationController(ref));

class CatalogMedicationState {
  final bool loading;
  final String? error;
  final String search;
  final int limit;
  final List<CatalogMedication> items;

  const CatalogMedicationState({
    this.loading = false,
    this.error,
    this.search = '',
    this.limit = 20,
    this.items = const [],
  });

  CatalogMedicationState copyWith({
    bool? loading,
    String? error, // '' clears
    String? search,
    int? limit,
    List<CatalogMedication>? items,
  }) {
    return CatalogMedicationState(
      loading: loading ?? this.loading,
      error: (error == '') ? null : (error ?? this.error),
      search: search ?? this.search,
      limit: limit ?? this.limit,
      items: items ?? this.items,
    );
  }
}

class CatalogMedicationController
    extends StateNotifier<CatalogMedicationState> {
  CatalogMedicationController(this.ref) : super(const CatalogMedicationState());
  final Ref ref;

  CatalogMedicationService get _svc =>
      ref.read(catalogMedicationServiceProvider);
  RxnormImportService get _importSvc => ref.read(rxnormImportServiceProvider);

  Timer? _debounce;

  Future<void> load({String? query, int? limit}) async {
    if (!mounted) return;
    final q = (query ?? state.search).trim();
    debugPrint(
      '🔎 [CatalogMedicationController] load() → query="$q" limit=${limit ?? state.limit}',
    );

    state = state.copyWith(
      loading: true,
      search: q,
      limit: limit ?? state.limit,
      error: '',
    );

    try {
      final items = q.isEmpty
          ? <CatalogMedication>[]
          : await _svc.search(query: q, limit: state.limit);

      if (!mounted) return;
      debugPrint(
        '✅ [CatalogMedicationController] load() complete → ${items.length} items',
      );

      state = state.copyWith(loading: false, items: items, error: '');
    } catch (e, st) {
      debugPrint('🧨 [CatalogMedicationController] load() failed: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e.toString());
      SnackService.showError('❌ Failed to search catalog: $e');
    }
  }

  /// UI calls this directly; we own debounce + trimming.
  void setSearch(String q) {
    final v = q.trim();
    debugPrint('⌨️ [CatalogMedicationController] setSearch("$v")');
    state = state.copyWith(search: v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => load());
  }

  /// Explicit clear — keeps UI dumb.
  void clearSearch() {
    debugPrint('🧹 [CatalogMedicationController] clearSearch()');
    _debounce?.cancel();
    state = state.copyWith(search: '', items: const [], error: '');
  }

  void setLimit(int limit) {
    final safe = limit.clamp(5, 200);
    debugPrint(
      '📊 [CatalogMedicationController] setLimit($limit) → safe=$safe',
    );
    state = state.copyWith(limit: safe);
    load();
  }

  Future<void> refresh() {
    debugPrint('🔄 [CatalogMedicationController] refresh()');
    return load();
  }

  Future<void> rebuildSearchTerms(String id) async {
    debugPrint('🛠 [CatalogMedicationController] rebuildSearchTerms("$id")');
    try {
      await _svc.ensureSearchTerms(id);
      SnackService.showSuccess('🔎 Search index updated');
    } catch (e) {
      debugPrint(
        '🧨 [CatalogMedicationController] rebuildSearchTerms failed: $e',
      );
      SnackService.showError('❌ Index update failed: $e');
    }
  }

  Future<void> importByName(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    debugPrint('⬇️ [CatalogMedicationController] importByName("$n")');
    try {
      final id = await _importSvc.importByName(n);
      debugPrint(
        '✅ [CatalogMedicationController] importByName complete → RXCUI $id',
      );
      SnackService.showSuccess('✅ Imported • RXCUI $id');
      // reuse search box to show what was imported
      state = state.copyWith(search: n);
      await load();
    } catch (e) {
      debugPrint('🧨 [CatalogMedicationController] importByName failed: $e');
      SnackService.showError('❌ Import by name failed: $e');
    }
  }

  Future<void> importByRxcui(String rxcui) async {
    final id = rxcui.trim();
    if (id.isEmpty) return;
    debugPrint('⬇️ [CatalogMedicationController] importByRxcui("$id")');
    try {
      final saved = await _importSvc.importByRxcui(id);
      debugPrint(
        '✅ [CatalogMedicationController] importByRxcui complete → RXCUI $saved',
      );
      SnackService.showSuccess('✅ Imported • RXCUI $saved');
      state = state.copyWith(search: saved);
      await load();
    } catch (e) {
      debugPrint('🧨 [CatalogMedicationController] importByRxcui failed: $e');
      SnackService.showError('❌ Import by RXCUI failed: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('🗑 [CatalogMedicationController] dispose()');
    _debounce?.cancel();
    super.dispose();
  }
}
