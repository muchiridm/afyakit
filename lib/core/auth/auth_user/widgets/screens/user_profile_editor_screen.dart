import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/core/auth/auth_session/services/auth_service.dart';
import 'package:flutter/services.dart';
import 'package:afyakit/features/records/native_contacts/native_contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/auth/auth_user/controllers/profile_controller.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/user_status_x.dart';
import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';

/// Compatibility entry point. Self -> Native Contact, target user -> access administration.
class UserProfileEditorScreen extends ConsumerWidget {
  const UserProfileEditorScreen({super.key, this.user});
  final AuthUser? user;
  @override
  Widget build(BuildContext context, WidgetRef ref) => user == null
      ? const _MyContactEditor()
      : _AccountAdministration(target: user!);
}

class _MyContactEditor extends ConsumerStatefulWidget {
  const _MyContactEditor();
  @override
  ConsumerState<_MyContactEditor> createState() => _MyContactEditorState();
}

class _MyContactEditorState extends ConsumerState<_MyContactEditor> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _idNumber = TextEditingController();
  NativeContact? _contact;
  bool _initialised = false;
  bool _saving = false;
  bool _sendingEmailCode = false;
  String? _emailError;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final service = await ref.read(nativeContactsServiceProvider.future);
      final contact = await service.getMine();
      if (!mounted) return;
      setState(() {
        _contact = contact;
        _name.text = contact.displayName;
        _phone.text = contact.phone ?? '';
        _mobile.text = contact.mobile ?? '';
        _email.text = contact.email ?? '';
        _idNumber.text = contact.idNumber ?? '';
        _initialised = true;
        _error = null;
        _emailError = null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _initialised = true;
        _error = err.toString();
      });
    }
  }

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      final service = await ref.read(nativeContactsServiceProvider.future);
      final updated = await service.updateMine({
        'display_name': _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'mobile': _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'id_number': _idNumber.text.trim().isEmpty
            ? null
            : _idNumber.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _contact = updated;
        _error = null;
      });
      await ref
          .read(sessionControllerProvider(ref.read(tenantIdProvider)).notifier)
          .refresh(forceNetwork: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contact updated')));
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return null; // Contact email is optional.
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Never expose backend exception strings, email addresses, or OTP details.
  String _friendlyEmailError(Object error) {
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

  Future<void> _verifyEmail() async {
    if (_saving || _sendingEmailCode) return;
    final email = _email.text.trim().toLowerCase();
    if (email.isEmpty || _validateEmail(email) != null) {
      setState(() => _emailError = 'Enter a valid email address to verify.');
      return;
    }

    setState(() {
      _sendingEmailCode = true;
      _emailError = null;
    });
    try {
      final tenantId = ref.read(tenantIdProvider);
      final auth = await ref.read(authServiceProvider(tenantId).future);
      final started = await auth.startVerifyEmailOtp(email: email);
      if (!mounted) return;
      if (started.throttled == true) {
        setState(
          () => _emailError =
              'Too many verification requests. Please try again later.',
        );
        return;
      }
      final attemptId = (started.attemptId ?? '').trim();
      if (attemptId.isEmpty) {
        throw StateError('Email verification could not be started.');
      }
      // Return from the OTP route before refreshing global session state.
      // Refreshing under an active dialog can cause the parent navigator to
      // rebuild while its Overlay entries are still mounted.
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EmailVerificationDialog(
          auth: auth,
          email: email,
          attemptId: attemptId,
        ),
      );
      if (verified != true || !mounted) return;

      // Let the dialog pop be processed before publishing new auth state.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await ref
          .read(sessionControllerProvider(tenantId).notifier)
          .refresh(forceNetwork: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email verified for login')));
    } catch (err) {
      if (!mounted) return;
      setState(() => _emailError = _friendlyEmailError(err));
    } finally {
      if (mounted) setState(() => _sendingEmailCode = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _mobile, _email, _idNumber]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(tenantIdProvider);
    final verifiedEmail = ref
        .watch(sessionControllerProvider(tenantId))
        .valueOrNull
        ?.activeAppEmailLower;
    final emailMatches =
        verifiedEmail != null &&
        verifiedEmail.toLowerCase() == _email.text.trim().toLowerCase();

    return AppPage(
      maxWidth: 720,
      scrollable: true,
      header: const AppHeader(title: 'My Native Contact'),
      body: !_initialised
          ? const Center(child: CircularProgressIndicator())
          : _contact == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? 'Contact not available'),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Account number: ${_contact!.accountNumber}'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Name required' : null,
                    ),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText:
                            'Contact phone (not a verified login number)',
                      ),
                    ),
                    TextFormField(
                      controller: _mobile,
                      decoration: const InputDecoration(
                        labelText: 'Mobile (unverified)',
                      ),
                    ),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Contact email (optional)',
                        helperText:
                            'Verify an email to also sign in using email OTP.',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      onChanged: (_) => setState(() => _emailError = null),
                    ),
                    const SizedBox(height: 10),
                    if (emailMatches)
                      Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Verified for email OTP login'),
                          ),
                        ],
                      )
                    else ...[
                      if (_email.text.trim().isNotEmpty &&
                          _validateEmail(_email.text) == null &&
                          _emailError == null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Not yet verified for login'),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed:
                              (_saving ||
                                  _sendingEmailCode ||
                                  _email.text.trim().isEmpty ||
                                  _validateEmail(_email.text) != null)
                              ? null
                              : _verifyEmail,
                          icon: _sendingEmailCode
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.mark_email_unread_outlined),
                          label: Text(
                            _sendingEmailCode
                                ? 'Sending verification code…'
                                : 'Verify email for login',
                          ),
                        ),
                      ),
                    ],
                    if (_emailError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 19,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _emailError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _idNumber,
                      decoration: const InputDecoration(
                        labelText: 'Identification number',
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save contact'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// A dedicated route owns the OTP controller and its lifecycle.
/// Verification does not mutate the parent session until this route is popped.
class _EmailVerificationDialog extends StatefulWidget {
  const _EmailVerificationDialog({
    required this.auth,
    required this.email,
    required this.attemptId,
  });

  final AuthService auth;
  final String email;
  final String attemptId;

  @override
  State<_EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<_EmailVerificationDialog> {
  final _code = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_verifying) return;
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the six-digit code');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final result = await widget.auth.verifyEmailOtpAuthed(
        attemptId: widget.attemptId,
        code: code,
      );
      if (!result.ok) throw StateError('Invalid verification code');
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) {
        final message = err.toString().toUpperCase();
        setState(
          () => _error = message.contains('EXPIRED')
              ? 'This code has expired. Request a new code.'
              : message.contains('INVALID') || message.contains('WRONG')
              ? 'The code is incorrect. Please try again.'
              : 'We could not verify this code. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Verify email'),
    content: SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter the six-digit code sent to ${widget.email}.'),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            enabled: !_verifying,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Verification code',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _verifying ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _verifying ? null : _submit,
        child: _verifying
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Verify'),
      ),
    ],
  );
}

class _AccountAdministration extends ConsumerStatefulWidget {
  const _AccountAdministration({required this.target});
  final AuthUser target;
  @override
  ConsumerState<_AccountAdministration> createState() =>
      _AccountAdministrationState();
}

class _AccountAdministrationState
    extends ConsumerState<_AccountAdministration> {
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(profileControllerProvider(widget.target).notifier).init();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider(widget.target));
    final ctrl = ref.read(profileControllerProvider(widget.target).notifier);
    final u = state.user;
    return AppPage(
      maxWidth: 720,
      scrollable: true,
      header: const AppHeader(title: 'User administration'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.loading && u == null
            ? const Center(child: CircularProgressIndicator())
            : u == null
            ? const Text('User unavailable')
            : !state.isAdminEditing
            ? const Text('You are not authorised to administer this account.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('UID: ${u.uid}'),
                  Text('Account: ${u.accountNumber ?? '—'}'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserStatus>(
                    initialValue: state.statusOverride ?? u.status,
                    items: UserStatus.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) ctrl.setStatus(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('App-specific staff roles'),
                  Wrap(
                    spacing: 8,
                    children: StaffRole.values
                        .map(
                          (role) => FilterChip(
                            label: Text(role.label),
                            selected: (state.staffRoleOverrides ?? u.staffRoles)
                                .contains(role),
                            onSelected: (_) => ctrl.toggleStaffRole(role),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: state.loading ? null : () => ctrl.save(context),
                    child: const Text('Save account access'),
                  ),
                ],
              ),
      ),
    );
  }
}
