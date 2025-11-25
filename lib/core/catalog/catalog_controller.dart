// lib/core/catalog/catalog_controller.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_models.dart';
import 'catalog_service.dart';

@immutable
class CatalogState {
  final AsyncValue<List<CatalogTile>> items;
  final CatalogQuery query;
  final bool hasMore;
  final int offset;

  const CatalogState({
    required this.items,
    required this.query,
    required this.hasMore,
    required this.offset,
  });

  const CatalogState.initial()
    : items = const AsyncLoading(),
      query = const CatalogQuery(),
      hasMore = true,
      offset = 0;

  CatalogState copyWith({
    AsyncValue<List<CatalogTile>>? items,
    CatalogQuery? query,
    bool? hasMore,
    int? offset,
  }) {
    return CatalogState(
      items: items ?? this.items,
      query: query ?? this.query,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
    );
  }
}

class CatalogController extends StateNotifier<CatalogState> {
  CatalogController(CatalogService? service)
    : _service = service,
      super(const CatalogState.initial());

  CatalogController.empty()
    : _service = null,
      super(const CatalogState.initial());

  final CatalogService? _service;

  final List<CatalogTile> _acc = <CatalogTile>[];
  Timer? _debounce;

  // 👇 this identifies "the latest search"
  int _generation = 0;

  bool get hasMore => state.hasMore;
  CatalogQuery get query => state.query;
  bool get _ready => _service != null;

  /// Hard refresh (enter / form change)
  Future<void> refresh({CatalogQuery? query}) async {
    _debounce?.cancel();

    // every explicit refresh = new generation
    _generation++;
    final currentGen = _generation;

    // if not ready, just update local state
    if (!_ready) {
      state = state.copyWith(
        query: query ?? state.query,
        items: const AsyncLoading(),
        hasMore: true,
        offset: 0,
      );
      return;
    }

    _acc.clear();
    state = state.copyWith(
      query: query ?? state.query,
      hasMore: true,
      offset: 0,
      items: const AsyncLoading(),
    );

    await _loadPage(
      gen: currentGen,
      query: query ?? state.query,
      offset: 0,
      append: false,
    );
  }

  /// Debounced refresh (keystrokes)
  void refreshDebounced({CatalogQuery? query, Duration? delay}) {
    _debounce?.cancel();
    // we increment generation *when* we actually refresh, not here
    _debounce = Timer(delay ?? const Duration(milliseconds: 420), () {
      refresh(query: query);
    });
  }

  /// Scroll to load more
  Future<void> loadMore() async {
    if (!_ready) return;
    if (!state.hasMore) return;

    final currentGen = _generation;

    await _loadPage(
      gen: currentGen,
      query: state.query,
      offset: state.offset,
      append: true,
    );
  }

  /// actual fetch, guarded by generation
  Future<void> _loadPage({
    required int gen,
    required CatalogQuery query,
    required int offset,
    required bool append,
  }) async {
    try {
      final (items, hasMore) = await _service!.fetchTiles(
        offset: offset,
        limit: 50,
        query: query,
      );

      // 👇 if a newer search started while we were waiting, ignore this result
      if (gen != _generation) {
        return;
      }

      if (append) {
        _acc.addAll(items);
      } else {
        _acc
          ..clear()
          ..addAll(items);
      }

      state = state.copyWith(
        items: AsyncData(List.unmodifiable(_acc)),
        hasMore: hasMore,
        offset: _acc.length,
      );
    } catch (e, st) {
      // also guard errors – don't overwrite a newer search with an error
      if (gen != _generation) return;
      state = state.copyWith(items: AsyncError(e, st));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
