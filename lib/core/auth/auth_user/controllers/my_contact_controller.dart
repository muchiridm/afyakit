// lib/core/auth/auth_user/controllers/my_contact_controller.dart
// Self-service orchestration only. Native Contacts owns contact data;
// Auth/session services own verified authentication channels.

import 'package:afyakit/core/auth/auth_session/services/auth_service.dart';
import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/native_contacts_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyContactState {
  const MyContactState({
    this.contact,
    this.loading = true,
    this.saving = false,
    this.sendingEmailCode = false,
    this.error,
    this.emailError,
  });

  final NativeContact? contact;
  final bool loading;
  final bool saving;
  final bool sendingEmailCode;
  final String? error;
  final String? emailError;

  MyContactState copyWith({
    NativeContact? contact,
    bool? loading,
    bool? saving,
    bool? sendingEmailCode,
    String? error,
    String? emailError,
    bool clearError = false,
    bool clearEmailError = false,
  }) => MyContactState(
    contact: contact ?? this.contact,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    sendingEmailCode: sendingEmailCode ?? this.sendingEmailCode,
    error: clearError ? null : error ?? this.error,
    emailError: clearEmailError ? null : emailError ?? this.emailError,
  );
}

final myContactControllerProvider =
    StateNotifierProvider.autoDispose<MyContactController, MyContactState>(
  (ref) => MyContactController(ref),
);

class MyContactController extends StateNotifier<MyContactState> {
  MyContactController(this.ref) : super(const MyContactState());
  final Ref ref;

  static String? validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return null;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String friendlyEmailError(Object error) {
    final message = error.toString().toUpperCase();
    if (message.contains('EMAIL_IN_USE')) {
      return 'This email is already linked to another account in this app. '
          'Please use a different email address.';
    }
    if (message.contains('INVALID_EMAIL')) {
      return 'Please enter a valid email address.';
    }
    if (message.contains('THROTTL') ||
        message.contains('TOO_MANY') ||
        message.contains('RATE_LIMIT') ||
        message.contains('HTTP 429')) {
      return 'Too many verification requests. Please try again later.';
    }
    if (message.contains('HTTP 401') || message.contains('UNAUTHENTICATED')) {
      return 'Your session has expired. Please sign in again.';
    }
    return 'We could not send the verification code. Please try again.';
  }

  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final service = await ref.read(nativeContactsServiceProvider.future);
      final contact = await service.getMine();
      if (!mounted) return;
      state = state.copyWith(
        contact: contact,
        loading: false,
        clearError: true,
        clearEmailError: true,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        error: 'Could not load your Native Contact. Please retry.',
      );
    }
  }

  Future<bool> save({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String idNumber,
  }) async {
    if (!mounted || state.saving || state.contact?.isPerson != true) {
      return false;
    }
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      state = state.copyWith(error: 'First name and last name are required.');
      return false;
    }
    if (validateEmail(email) != null) {
      state = state.copyWith(error: 'Enter a valid contact email.');
      return false;
    }
    state = state.copyWith(saving: true, clearError: true);
    try {
      final service = await ref.read(nativeContactsServiceProvider.future);
      final updated = await service.updateMine({
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'phone': phone.trim().isEmpty ? null : phone.trim(),
        'email': email.trim().isEmpty ? null : email.trim(),
        'id_number': idNumber.trim().isEmpty ? null : idNumber.trim(),
      });
      if (!mounted) return false;
      state = state.copyWith(contact: updated, clearError: true);
      final tenantId = ref.read(tenantIdProvider);
      await ref.read(sessionControllerProvider(tenantId).notifier)
          .refresh(forceNetwork: true);
      return mounted;
    } catch (error) {
      if (mounted) state = state.copyWith(error: error.toString());
      return false;
    } finally {
      if (mounted) state = state.copyWith(saving: false);
    }
  }

  void clearEmailError() {
    if (mounted) state = state.copyWith(clearEmailError: true);
  }

  Future<String?> startEmailVerification(String email) async {
    if (!mounted || state.saving || state.sendingEmailCode) return null;
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || validateEmail(normalized) != null) {
      state = state.copyWith(emailError: 'Enter a valid email address to verify.');
      return null;
    }
    state = state.copyWith(sendingEmailCode: true, clearEmailError: true);
    try {
      final tenantId = ref.read(tenantIdProvider);
      final auth = await ref.read(authServiceProvider(tenantId).future);
      final started = await auth.startVerifyEmailOtp(email: normalized);
      if (!mounted) return null;
      if (started.throttled == true) {
        state = state.copyWith(
          emailError: 'Too many verification requests. Please try again later.',
        );
        return null;
      }
      final attemptId = (started.attemptId ?? '').trim();
      if (attemptId.isEmpty) {
        state = state.copyWith(
          emailError: 'Could not start email verification. Please try again.',
        );
        return null;
      }
      return attemptId;
    } catch (error) {
      if (mounted) state = state.copyWith(emailError: friendlyEmailError(error));
      return null;
    } finally {
      if (mounted) state = state.copyWith(sendingEmailCode: false);
    }
  }

  Future<bool> verifyEmailCode({
    required String attemptId,
    required String code,
  }) async {
    final tenantId = ref.read(tenantIdProvider);
    final auth = await ref.read(authServiceProvider(tenantId).future);
    final result = await auth.verifyEmailOtpAuthed(
      attemptId: attemptId,
      code: code,
    );
    return result.ok;
  }

  Future<void> refreshSessionAfterEmailVerification() async {
    final tenantId = ref.read(tenantIdProvider);
    await ref.read(sessionControllerProvider(tenantId).notifier)
        .refresh(forceNetwork: true);
  }
}
