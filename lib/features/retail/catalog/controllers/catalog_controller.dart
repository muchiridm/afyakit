import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog_models.dart';
import '../catalog_service.dart';

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
      super(const CatalogState.initial()) {
    if (_service != null) {
      // ignore: discarded_futures
      refresh();
    }
  }

  CatalogService? _service;

  final List<CatalogTile> _acc = <CatalogTile>[];
  Timer? _debounce;
  int _generation = 0;

  bool get hasMore => state.hasMore;
  CatalogQuery get query => state.query;
  bool get _ready => _service != null;

  /// Called when AfyaKitClient becomes ready later
  void setService(CatalogService service) {
    if (_service != null) return;
    _service = service;

    // ignore: discarded_futures
    refresh();
  }

  /// Hard refresh
  Future<void> refresh({CatalogQuery? query}) async {
    _debounce?.cancel();

    _generation++;
    final currentGen = _generation;

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

  /// Debounced search
  void refreshDebounced({CatalogQuery? query, Duration? delay}) {
    _debounce?.cancel();
    _debounce = Timer(delay ?? const Duration(milliseconds: 420), () {
      refresh(query: query);
    });
  }

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

      // Controller disposed while waiting
      if (!mounted) return;

      // Ignore stale generation
      if (gen != _generation) return;

      if (append) {
        _acc.addAll(items);
      } else {
        _acc
          ..clear()
          ..addAll(items);
      }

      if (!mounted) return;

      state = state.copyWith(
        items: AsyncData(List.unmodifiable(_acc)),
        hasMore: hasMore,
        offset: _acc.length,
      );
    } catch (e, st) {
      if (!mounted) return;
      if (gen != _generation) return;

      state = state.copyWith(items: AsyncError(e, st));
    }
  }
}
