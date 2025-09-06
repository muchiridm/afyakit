class ActiveTempSession {
  final String deliveryId;
  final String enteredByEmail;
  final String? enteredByName;
  final String? lastStoreId;
  final String? lastSource;
  ActiveTempSession({
    required this.deliveryId,
    required this.enteredByEmail,
    this.enteredByName,
    this.lastStoreId,
    this.lastSource,
  });
}
