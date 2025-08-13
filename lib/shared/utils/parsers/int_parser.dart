// File: lib/shared/utils/parsers/int_parser.dart

import 'dart:developer';

int? parseInt(dynamic value) {
  try {
    if (value == null) return null;

    if (value is int) return value;
    if (value is double) return value.toInt(); // 💥 This is key!
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.contains('.')) {
        final doubleVal = double.tryParse(trimmed);
        return doubleVal?.toInt();
      }
      return int.tryParse(trimmed);
    }

    return int.tryParse(value.toString());
  } catch (e, stack) {
    log('❌ parseInt failed on value: $value', stackTrace: stack);
    return null;
  }
}
