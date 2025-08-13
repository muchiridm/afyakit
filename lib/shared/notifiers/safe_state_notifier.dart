import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class SafeStateNotifier<T> extends StateNotifier<T> {
  bool _mounted = true;
  @override
  bool get mounted => _mounted;

  SafeStateNotifier(super.state);

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }
}
