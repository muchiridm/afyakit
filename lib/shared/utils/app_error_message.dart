// lib/shared/utils/app_error_message.dart

String appErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again shortly.',
}) {
  final text = error.toString().toLowerCase();

  if (text.contains('502') ||
      text.contains('503') ||
      text.contains('504') ||
      text.contains('bad gateway') ||
      text.contains('temporarily unavailable')) {
    return 'This service is temporarily unavailable. We may be updating our database right now. Please try again in a minute.';
  }

  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection') ||
      text.contains('network')) {
    return 'Please check your internet connection and try again.';
  }

  if (text.contains('timeout')) {
    return 'The request is taking longer than expected. Please try again shortly.';
  }

  return fallback;
}
