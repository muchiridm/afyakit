// lib/features/retail/catalog/catalog_controller.dart

import 'dart:async';

import 'package:afyakit/features/retail/catalog/models/catalog_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_service.dart';

@immutable
class CatalogState {
  final AsyncValue<List<CatalogTile>> items;
  final CatalogQuery query;
  final bool hasMore;
  final int offset;
  final bool exporting;

  const CatalogState({
    required this.items,
    required this.query,
    required this.hasMore,
    required this.offset,
    required this.exporting,
  });

  const CatalogState.initial()
    : items = const AsyncData(<CatalogTile>[]),
      query = const CatalogQuery(),
      hasMore = false,
      offset = 0,
      exporting = false;

  CatalogState copyWith({
    AsyncValue<List<CatalogTile>>? items,
    CatalogQuery? query,
    bool? hasMore,
    int? offset,
    bool? exporting,
  }) {
    return CatalogState(
      items: items ?? this.items,
      query: query ?? this.query,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      exporting: exporting ?? this.exporting,
    );
  }

  bool get isDiscoveryMode => query.normalized.isDiscoveryMode;
}

class CatalogController extends StateNotifier<CatalogState> {
  CatalogController(this._service) : super(const CatalogState.initial());

  final CatalogService _service;

  final List<CatalogTile> _acc = <CatalogTile>[];
  Timer? _debounce;
  int _generation = 0;
  bool _loadingMore = false;

  Future<void> refresh({CatalogQuery? query}) async {
    _debounce?.cancel();

    if (!mounted) return;

    final CatalogQuery baseQuery = query ?? state.query;
    final CatalogQuery nextQuery = baseQuery.normalized;

    _generation++;
    final int currentGen = _generation;
    _loadingMore = false;
    _acc.clear();

    if (nextQuery.isDiscoveryMode) {
      state = state.copyWith(
        query: nextQuery,
        items: const AsyncData(<CatalogTile>[]),
        hasMore: false,
        offset: 0,
      );
      return;
    }

    state = state.copyWith(
      query: nextQuery,
      hasMore: true,
      offset: 0,
      items: const AsyncLoading(),
    );

    await _loadPage(
      gen: currentGen,
      query: nextQuery,
      offset: 0,
      append: false,
    );
  }

  void refreshDebounced({CatalogQuery? query, Duration? delay}) {
    _debounce?.cancel();

    if (!mounted) return;

    final CatalogQuery baseQuery = query ?? state.query;
    final CatalogQuery nextQuery = baseQuery.normalized;

    if (nextQuery.isDiscoveryMode) {
      // ignore: discarded_futures
      refresh(query: nextQuery);
      return;
    }

    _debounce = Timer(delay ?? const Duration(milliseconds: 420), () {
      if (!mounted) return;
      // ignore: discarded_futures
      refresh(query: nextQuery);
    });
  }

  Future<void> loadMore() async {
    if (!mounted) return;
    if (_loadingMore) return;

    final CatalogState current = state;
    if (current.isDiscoveryMode) return;
    if (!current.hasMore) return;

    _loadingMore = true;
    final int currentGen = _generation;

    try {
      await _loadPage(
        gen: currentGen,
        query: current.query.normalized,
        offset: current.offset,
        append: true,
      );
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _loadPage({
    required int gen,
    required CatalogQuery query,
    required int offset,
    required bool append,
  }) async {
    if (!mounted) return;

    try {
      final (items, hasMore) = await _service.fetchTiles(
        offset: offset,
        limit: 50,
        query: query,
      );

      if (!mounted) return;
      if (gen != _generation) return;

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
      if (!mounted) return;
      if (gen != _generation) return;

      state = state.copyWith(items: AsyncError(e, st), hasMore: false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation++;
    _loadingMore = false;
    super.dispose();
  }
}
