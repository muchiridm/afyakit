import 'package:flutter/material.dart';

@immutable
class HqLoginState {
  final bool isLoading;
  final String? error;
  final String? email;
  final bool isHqAllowed; // replaces isSuperAdmin

  const HqLoginState({
    this.isLoading = false,
    this.error,
    this.email,
    this.isHqAllowed = false,
  });

  HqLoginState copyWith({
    bool? isLoading,
    String? error, // '' clears
    String? email,
    bool? isHqAllowed,
  }) {
    return HqLoginState(
      isLoading: isLoading ?? this.isLoading,
      error: (error == '') ? null : (error ?? this.error),
      email: email ?? this.email,
      isHqAllowed: isHqAllowed ?? this.isHqAllowed,
    );
  }
}
