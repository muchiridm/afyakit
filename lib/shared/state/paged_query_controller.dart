// lib/shared/state/paged_query_controller.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base state for "list + optional query + pagination".
/// Keep it generic, not Zoho-specific.
class PagedQueryState<T> {
  const PagedQueryState({
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.q = '',
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
  });

  final bool loading;
  final bool loadingMore;
  final String? error;

  final String q;
  final List<T> items;

  final int page;
  final bool hasMore;

  PagedQueryState<T> copyWith({
    bool? loading,
    bool? loadingMore,
    String? error,
    String? q,
    List<T>? items,
    int? page,
    bool? hasMore,
  }) {
    return PagedQueryState<T>(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
      q: q ?? this.q,
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Fetch result for one page.
class PageResult<T> {
  const PageResult({required this.items, required this.hasMore});
  final List<T> items;
  final bool hasMore;
}

/// Generic controller:
/// - debounce search
/// - refresh(reset: true)
/// - loadMore()
abstract class PagedQueryController<T>
    extends StateNotifier<PagedQueryState<T>> {
  PagedQueryController() : super(PagedQueryState<T>());

  Timer? _debounce;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    super.dispose();
  }

  /// Override: fetch items for a page.
  Future<PageResult<T>> fetchPage({
    required String? q,
    required int page,
    required int limit,
  });

  /// Optional: customize debounce duration
  Duration get debounceDuration => const Duration(milliseconds: 350);

  void setQuery(String v) {
    state = state.copyWith(q: v, error: null);

    _debounce?.cancel();
    _debounce = Timer(debounceDuration, () {
      refresh(reset: true);
    });
  }

  Future<void> refresh({required bool reset, int limit = 50}) async {
    final seq = ++_seq;

    final q = state.q.trim();
    final query = q.isEmpty ? null : q;

    final page = reset ? 1 : state.page;

    state = state.copyWith(
      loading: reset ? true : state.loading,
      loadingMore: reset ? false : true,
      error: null,
      items: reset ? const [] : state.items,
      page: page,
      hasMore: reset ? true : state.hasMore,
    );

    try {
      final res = await fetchPage(q: query, page: page, limit: limit);

      if (!mounted) return;
      if (seq != _seq) return;

      final merged = reset ? res.items : <T>[...state.items, ...res.items];

      state = state.copyWith(
        loading: false,
        loadingMore: false,
        items: merged,
        hasMore: res.hasMore,
      );
    } catch (e) {
      if (!mounted) return;
      if (seq != _seq) return;

      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore({int limit = 50}) async {
    if (state.loading || state.loadingMore || !state.hasMore) return;

    state = state.copyWith(page: state.page + 1);
    await refresh(reset: false, limit: limit);
  }
}
