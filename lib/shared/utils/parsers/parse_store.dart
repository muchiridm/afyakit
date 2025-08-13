String parseStore(dynamic store, String fallbackPath) {
  if (store is String && store.trim().isNotEmpty) return store.trim();
  final parts = fallbackPath.split('/');
  final i = parts.indexOf('stores');
  return (i != -1 && parts.length > i + 1) ? parts[i + 1] : 'Unknown';
}
