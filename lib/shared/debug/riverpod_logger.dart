// lib/shared/debug/riverpod_logger.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RiverpodLogger extends ProviderObserver {
  const RiverpodLogger();

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    // Log AsyncError transitions
    if (newValue is AsyncValue && newValue.hasError) {
      debugPrint('💥 Provider error: ${provider.name ?? provider.runtimeType}');
      debugPrint('   error: ${newValue.error}');
      final st = newValue.stackTrace;
      if (st != null) debugPrintStack(stackTrace: st);
    }
  }
}
