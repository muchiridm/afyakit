class DevAuthResult {
  final bool success;
  final bool claimsSynced;
  final String? message;

  const DevAuthResult({
    required this.success,
    required this.claimsSynced,
    this.message,
  });
}
