// File: lib/shared/utils/parse/domain/store.dart

/// Resolves store id from either:
/// - [store] string
/// - or by extracting after 'stores' segment from [fallbackPath]
///
/// Examples:
/// fallbackPath: "tenants/x/stores/store_001/items/abc"
/// -> "store_001"
String parseStore(Object? store, String fallbackPath) {
  if (store is String) {
    final s = store.trim();
    if (s.isNotEmpty) return s;
  }

  final path = fallbackPath.trim();
  if (path.isEmpty) return 'Unknown';

  final parts = path.split('/');
  final i = parts.indexOf('stores');

  if (i != -1 && parts.length > i + 1) {
    final storeId = parts[i + 1].trim();
    if (storeId.isNotEmpty) return storeId;
  }

  return 'Unknown';
}
