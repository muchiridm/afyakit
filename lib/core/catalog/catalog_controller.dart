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

///
/// Controller that can work in two modes:
/// 1. normal → `_service` is non-null → we fetch
/// 2. idle   → `_service` is null → we ignore refresh/loadMore (for guest / client-not-ready)
///
class CatalogController extends StateNotifier<CatalogState> {
  CatalogController(CatalogService? service)
    : _service = service,
      super(const CatalogState.initial());

  /// idle ctor for when service isn't ready yet
  CatalogController.empty()
    : _service = null,
      super(const CatalogState.initial());

  final CatalogService? _service;

  final List<CatalogTile> _acc = <CatalogTile>[];
  Timer? _debounce;

  bool get hasMore => state.hasMore;
  CatalogQuery get query => state.query;
  bool get _ready => _service != null;

  Future<void> refresh({CatalogQuery? query}) async {
    _debounce?.cancel();

    // if not ready, just update the query locally and show "empty loading"
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
    await loadMore();
  }

  void refreshDebounced({CatalogQuery? query, Duration? delay}) {
    _debounce?.cancel();
    _debounce = Timer(delay ?? const Duration(milliseconds: 320), () {
      // if not ready, still let refresh run – it will no-op fetch
      refresh(query: query);
    });
  }

  Future<void> loadMore() async {
    // not ready → nothing to fetch, but also no crash
    if (!_ready) return;
    if (!state.hasMore) return;

    try {
      final (items, hasMore) = await _service!.fetchTiles(
        offset: state.offset,
        limit: 50,
        query: state.query,
      );

      _acc.addAll(items);

      state = state.copyWith(
        items: AsyncData(List.unmodifiable(_acc)),
        hasMore: hasMore,
        offset: _acc.length,
      );
    } catch (e, st) {
      state = state.copyWith(items: AsyncError(e, st));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
