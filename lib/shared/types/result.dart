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

extension ResultX<T> on Result<T> {
  /// Pattern-match style (side-effect only).
  void when({void Function(T value)? ok, void Function(AppError error)? err}) {
    if (this is Ok<T>) {
      final v = (this as Ok<T>).value;
      if (ok != null) ok(v);
    } else {
      final e = (this as Err<T>).error;
      if (err != null) err(e);
    }
  }

  /// Functional pattern-match that RETURNS a value.
  R fold<R>({
    required R Function(T value) ok,
    required R Function(AppError error) err,
  }) {
    if (this is Ok<T>) return ok((this as Ok<T>).value);
    return err((this as Err<T>).error);
  }

  /// Handy accessors.
  T? valueOrNull() => this is Ok<T> ? (this as Ok<T>).value : null;
  AppError? errorOrNull() => this is Err<T> ? (this as Err<T>).error : null;

  /// Map success value; pass errors through untouched.
  Result<R> map<R>(R Function(T value) f) => this is Ok<T>
      ? Ok<R>(f((this as Ok<T>).value))
      : Err<R>((this as Err<T>).error);

  /// Map error; pass successes through untouched.
  Result<T> mapError(AppError Function(AppError e) f) =>
      this is Err<T> ? Err<T>(f((this as Err<T>).error)) : this;

  /// Run side-effects without changing the result.
  Result<T> tap({void Function(T value)? ok, void Function(AppError e)? err}) {
    when(ok: ok, err: err);
    return this;
  }

  /// Throw on error, return value on success (useful in tests/one-off flows).
  T expect(String message) {
    if (this is Ok<T>) return (this as Ok<T>).value;
    final e = (this as Err<T>).error;
    throw AppError(e.code, '$message: ${e.message}', cause: e.cause);
  }
}
