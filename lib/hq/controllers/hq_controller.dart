// lib/hq/core/controllers/hq_controller.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hq_state.dart';

final hqControllerProvider = StateNotifierProvider<HqController, HqState>(
  (ref) => HqController(ref),
);

class HqController extends StateNotifier<HqState> {
  HqController(this.ref) : super(const HqState());
  final Ref ref;

  // Navigation + Search (UI state)
  void setTab(int index) => state = state.copyWith(tabIndex: index);

  void setUserSearch(String q) {
    final v = q.trim();
    state = state.copyWith(userSearch: v);
    // ❌ remove the cross-feature mirror line:
    // ref.read(allUsersSearchProvider.notifier).state = v;  // <-- delete
  }

  // Busy / banners
  Future<T> withBusy<T>(
    BuildContext context,
    Future<T> Function() op, {
    String? success,
    String Function(Object, StackTrace)? errorBuilder,
  }) async {
    _setBusy(true);
    try {
      final out = await op();
      if (success != null && success.isNotEmpty) _banner(success);
      return out;
    } catch (e, st) {
      debugPrint('❌ [HQ.withBusy] $e\n$st');
      final msg = (errorBuilder != null) ? errorBuilder(e, st) : 'Error: $e';
      _banner(msg);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  void clearBanner() => state = state.copyWith(banner: '');
  void _setBusy(bool v) => state = state.copyWith(busy: v);
  void _banner(String msg) => state = state.copyWith(banner: msg);
}
