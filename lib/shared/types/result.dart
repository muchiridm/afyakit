// lib/shared/types/result.dart
import 'package:afyakit/shared/types/app_error.dart';

sealed class Result<T> {
  const Result();
  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;
  T unwrapOr(T fallback) => this is Ok<T> ? (this as Ok<T>).value : fallback;
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final AppError error;
  const Err(this.error);
}
