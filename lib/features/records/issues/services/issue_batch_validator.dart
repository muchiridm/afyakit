import 'package:afyakit/features/batches/models/batch_record.dart';

class IssueBatchValidator {
  /// Returns a list of invalid batch IDs that are present in the cart
  /// but missing from the list of valid batch records.
  static List<String> findInvalidBatches(
    Map<String, Map<String, int>> cart,
    List<BatchRecord> batchList,
  ) {
    final validIds = batchList.map((b) => b.id).toSet();
    final invalid = <String>[];

    cart.forEach((_, batchMap) {
      for (final batchId in batchMap.keys) {
        if (!validIds.contains(batchId)) invalid.add(batchId);
      }
    });

    return invalid;
  }

  /// Returns batch IDs in the cart that have zero or negative quantity
  static List<String> findZeroOrNegativeQuantityBatches(
    Map<String, Map<String, int>> cart,
  ) {
    final zeroes = <String>[];

    cart.forEach((_, batchMap) {
      for (final entry in batchMap.entries) {
        if (entry.value <= 0) zeroes.add(entry.key);
      }
    });

    return zeroes;
  }

  /// Returns all unique batch IDs referenced in the cart
  static Set<String> extractBatchIds(Map<String, Map<String, int>> cart) {
    final ids = <String>{};
    cart.forEach((_, batchMap) => ids.addAll(batchMap.keys));
    return ids;
  }
}
