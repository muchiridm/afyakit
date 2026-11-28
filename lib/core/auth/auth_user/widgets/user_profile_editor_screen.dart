import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/auth/auth_user/controllers/profile_controller.dart';
import 'package:afyakit/core/auth/auth_user/controllers/my_contact_controller.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
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
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController(); // Native Contact only.
  final _loginEmail =
      TextEditingController(); // App-scoped authentication only.
  final _idNumber = TextEditingController();
  bool _initialisedFields = false;
  String? _otpError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(myContactControllerProvider.notifier).load();
    });
  }

  void _populateContact(NativeContact contact) {
    if (_initialisedFields) return;
    _initialisedFields = true;
    _firstName.text = contact.firstName ?? '';
    _lastName.text = contact.lastName ?? '';
    _phone.text = contact.phone ?? '';
    _email.text = contact.email ?? '';
    _idNumber.text = contact.idNumber ?? '';
    final tenantId = ref.read(tenantIdProvider);
    final verifiedLoginEmail = ref
        .read(sessionControllerProvider(tenantId))
        .valueOrNull
        ?.activeAppEmailLower;
    _loginEmail.text = verifiedLoginEmail ?? '';
  }

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    final saved = await ref.read(myContactControllerProvider.notifier).save(
      firstName: _firstName.text,
      lastName: _lastName.text,
      phone: _phone.text,
      email: _email.text,
      idNumber: _idNumber.text,
    );
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact updated')),
    );
  }

  Future<void> _verifyEmail() async {
    final email = _loginEmail.text.trim().toLowerCase();
    final ctrl = ref.read(myContactControllerProvider.notifier);
    final attemptId = await ctrl.startEmailVerification(email);
    if (!mounted || attemptId == null) return;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EmailVerificationDialog(
        onVerify: (code) => ctrl.verifyEmailCode(
          attemptId: attemptId,
          code: code,
        ),
        email: email,
      ),
    );
    if (verified != true || !mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await ctrl.refreshSessionAfterEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verified for login')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _otpError =
          'Email verified. Refresh the page to update its status.');
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _phone,
      _email,
      _loginEmail,
      _idNumber,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(tenantIdProvider);
    final contactState = ref.watch(myContactControllerProvider);
    final contact = contactState.contact;
    if (contact != null && !_initialisedFields) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _populateContact(contact));
      });
    }
    final authUser = ref.watch(sessionControllerProvider(tenantId)).valueOrNull;
    final verifiedPhone = authUser?.isPhoneSatisfiedResolved == true
        ? authUser?.phoneNumber
        : null;
    final verifiedEmail = authUser?.activeAppEmailLower;
    final emailMatches =
        verifiedEmail != null &&
        verifiedEmail.toLowerCase() == _loginEmail.text.trim().toLowerCase();

    return AppPage(
      maxWidth: 720,
      scrollable: true,
      header: const AppHeader(title: 'My Native Contact'),
      body: contactState.loading
          ? const Center(child: CircularProgressIndicator())
          : contact == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(contactState.error ?? 'Contact not available'),
                  TextButton(onPressed: () => ref.read(myContactControllerProvider.notifier).load(), child: const Text('Retry')),
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
                    Text('Account number: ${contact.accountNumber}'),
                    const SizedBox(height: 16),
                    if (contact.isPerson) ...[
                      TextFormField(
                        controller: _firstName,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'First name required'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _lastName,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Last name required'
                            : null,
                      ),
                    ] else
                      Text('Organisation: ${contact.displayName}'),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText:
                            'Contact phone (not a verified login number)',
                      ),
                    ),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Contact email (optional)',
                        helperText:
                            'Contact detail only; not used to authenticate.',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: MyContactController.validateEmail,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _idNumber,
                      decoration: const InputDecoration(
                        labelText: 'Identification number',
                      ),
                    ),
                    const Divider(height: 32),
                    const SizedBox(height: 24),
                    const Text('Login & security'),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey('verified-phone-${verifiedPhone ?? 'none'}'),
                      initialValue: verifiedPhone ?? '',
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Verified login phone',
                        helperText: 'Primary authentication identity; not your contact phone.',
                        suffixIcon: Icon(verifiedPhone == null
                            ? Icons.lock_outline : Icons.verified_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _loginEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email for OTP login (optional)',
                        helperText:
                            'Verified per app. Changing this does not edit your Native Contact.',
                      ),
                      onChanged: (_) => ref.read(myContactControllerProvider.notifier).clearEmailError(),
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
                      if (_loginEmail.text.trim().isNotEmpty &&
                          MyContactController.validateEmail(_loginEmail.text) == null &&
                          contactState.emailError == null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Not yet verified for login'),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed:
                              (contactState.saving ||
                                  contactState.sendingEmailCode ||
                                  _loginEmail.text.trim().isEmpty ||
                                  MyContactController.validateEmail(_loginEmail.text) != null)
                              ? null
                              : _verifyEmail,
                          icon: contactState.sendingEmailCode
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.mark_email_unread_outlined),
                          label: Text(
                            contactState.sendingEmailCode
                                ? 'Sending verification code…'
                                : 'Verify email for login',
                          ),
                        ),
                      ),
                    ],
                    if (contactState.emailError != null)
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
                                contactState.emailError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (contactState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          contactState.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_otpError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_otpError!),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: contactState.saving || !contact.isPerson ? null : _save,
                      child: Text(contactState.saving ? 'Saving…' : 'Save contact'),
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
    required this.onVerify,
    required this.email,
  });

  final Future<bool> Function(String code) onVerify;
  final String email;

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
      final verified = await widget.onVerify(code);
      if (!verified) throw StateError('Invalid verification code');
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
    final actor = ref.watch(currentUserValueProvider);
    final canStatus = u != null && actor?.canChangeStatusFor(u) == true;
    final canRoles = u != null && actor?.canEditUserRolesFor(u) == true;
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
                    onChanged: canStatus
                        ? (value) {
                            if (value != null) ctrl.setStatus(value);
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('App-specific staff roles'),
                  const Text(
                    'Professional assignments require independent approval and protected revocation.',
                  ),
                  Wrap(
                    spacing: 8,
                    children: StaffRole.values
                        .map(
                          (role) => FilterChip(
                            label: Text(role.label),
                            selected: (state.staffRoleOverrides ?? u.staffRoles)
                                .contains(role),
                            onSelected: canRoles && !role.isProfessional
                                ? (_) => ctrl.toggleStaffRole(role)
                                : null,
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
