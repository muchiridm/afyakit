// lib/shared/types/app_error.dart
class AppError implements Exception {
  final String code; // e.g. 'auth/not-registered', 'net/timeout'
  final String message;
  final Object? cause;
  AppError(this.code, this.message, {this.cause});
}
