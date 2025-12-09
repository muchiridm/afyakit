class TempSession {
  final String deliveryId;
  final String? enteredByName;
  final String enteredByEmail;
  final List<String> sources;
  final String? lastStoreId;
  final String? lastSource;

  TempSession({
    required this.deliveryId,
    required this.enteredByName,
    required this.enteredByEmail,
    required this.sources,
    this.lastStoreId,
    this.lastSource,
  });
}
