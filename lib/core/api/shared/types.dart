// lib/core/api/shared/types.dart

class Paged<T> {
  final List<T> items;
  final int? nextOffset;

  const Paged({required this.items, required this.nextOffset});
}
