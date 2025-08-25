abstract class BatchLike {
  DateTime? get receivedDate;
  DateTime? get expiryDate;
  String? get storeId;
  String? get source;
  String get quantity;
  String get editReason;

  String generatedId();
}
