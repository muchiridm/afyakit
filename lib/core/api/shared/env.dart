// lib/core/api/shared/env.dart

String trimTrailingSlashes(String v) => v.trim().replaceAll(RegExp(r'/+$'), '');
