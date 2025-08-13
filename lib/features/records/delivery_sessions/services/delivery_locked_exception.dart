// lib/features/records/issues/services/delivery_locked_exception.dart
class DeliveryLockedException implements Exception {
  final String message;
  DeliveryLockedException([
    this.message =
        'Stock changes are blocked: an active delivery session is in progress.',
  ]);
  @override
  String toString() => 'DeliveryLockedException: $message';
}
