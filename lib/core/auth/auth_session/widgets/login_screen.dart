// lib/core/auth/auth_session/widgets/login_screen.dart

import 'package:afyakit/core/auth/auth_session/controllers/login_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    required this.copy,
    this.backgroundColor = const Color(0xFFFDF8FF),
  });

  final OtpLoginCopy copy;
  final Color backgroundColor;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  final _emailCtrl = TextEditingController();
  final _emailOtpCtrl = TextEditingController();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();

  ProviderSubscription<LoginState>? _sub;

  LoginController get _ctrl => ref.read(loginControllerProvider.notifier);

  @override
  void initState() {
    super.initState();

    _sub = ref.listenManual<LoginState>(loginControllerProvider, (prev, next) {
      final prevStep = prev?.step;
      final nextStep = next.step;

      if (prevStep != nextStep) {
        switch (nextStep) {
          case LoginStep.phone:
            _otpCtrl.clear();
            _emailOtpCtrl.clear();
            break;
          case LoginStep.otp:
            _otpCtrl.clear();
            break;
          case LoginStep.emailEntry:
            _emailOtpCtrl.clear();
            break;
          case LoginStep.emailOtp:
            _emailOtpCtrl.clear();
            break;
          case LoginStep.nameEntry:
            // keep user input; do not auto-mutate here (UI stays dumb)
            break;
        }
      }

      if (next.closeScreen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).maybePop(true);
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.close();
    _sub = null;

    _phoneCtrl.dispose();
    _otpCtrl.dispose();

    _emailCtrl.dispose();
    _emailOtpCtrl.dispose();

    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _displayNameCtrl.dispose();
    _companyCtrl.dispose();

    super.dispose();
  }

  void _close() {
    _ctrl.reset();
    Navigator.of(context).maybePop(false);
  }

  String _modeLabel(LoginState state) {
    final ch = (state.channel ?? '').trim().toLowerCase();
    if (ch == 'sms') return 'SMS';
    if (ch == 'email') return 'email';
    return 'code';
  }

  bool _looksLikeEmail(String v) {
    final s = v.trim();
    return s.isNotEmpty && s.contains('@') && s.contains('.');
  }

  // ─────────────────────────────────────────────
  // Small UI helpers (keep screen clean)
  // ─────────────────────────────────────────────

  Widget _primaryButton({
    required bool enabled,
    required VoidCallback? onPressed,
    required bool busy,
    required String label,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }

  TextField _textField({
    required TextEditingController controller,
    required bool enabled,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool autofocus = false,
    List<TextInputFormatter>? inputFormatters,
    required InputDecoration decoration,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
      onSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: false,
      decoration: decoration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 20),
                      _StepHint(text: state.stepHint),
                      const SizedBox(height: 16),
                      switch (state.step) {
                        LoginStep.phone => _phoneStep(state),
                        LoginStep.otp => _otpStep(state),
                        LoginStep.emailEntry => _emailEntryStep(state),
                        LoginStep.emailOtp => _emailOtpStep(state),
                        LoginStep.nameEntry => _nameStep(state),
                      },
                      const SizedBox(height: 18),
                      if (state.busy) ...[
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            'Please wait…',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Close',
        onPressed: _close,
      ),
      title: Text(widget.copy.appTitle),
      centerTitle: true,
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final primary = theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.copy.headerTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.copy.headerSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: primary.withOpacity(0.85),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.copy.description,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Step UIs
  // ─────────────────────────────────────────────

  Widget _phoneStep(LoginState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _textField(
          controller: _phoneCtrl,
          enabled: !state.busy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+2547...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) {
            final phone = _phoneCtrl.text.trim();
            final can = phone.isNotEmpty && !state.busy;
            if (can) _ctrl.sendCode(phoneE164: phone);
          },
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _phoneCtrl,
          builder: (context, value, _) {
            final phone = value.text.trim();
            final canContinue = phone.isNotEmpty && !state.busy;

            return _primaryButton(
              enabled: canContinue,
              onPressed: () => _ctrl.sendCode(phoneE164: _phoneCtrl.text),
              busy: state.sending,
              label: 'Continue',
            );
          },
        ),
      ],
    );
  }

  Widget _otpStep(LoginState state) {
    final modeLabel = _modeLabel(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: state.busy
              ? null
              : () {
                  _otpCtrl.clear();
                  _ctrl.backToPhone();
                },
          child: const Text('Change phone number'),
        ),
        const SizedBox(height: 8),
        _textField(
          controller: _otpCtrl,
          enabled: !state.busy,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            labelText: 'Enter 6-digit $modeLabel code',
            border: const OutlineInputBorder(),
            isDense: true,
            counterText: '',
          ),
          onSubmitted: (_) {
            final code = _otpCtrl.text.trim();
            final can = code.length == 6 && !state.busy;
            if (can) _ctrl.verifyCode(code: code);
          },
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _otpCtrl,
          builder: (context, value, _) {
            final code = value.text.trim();
            final canVerify = code.length == 6 && !state.busy;

            return _primaryButton(
              enabled: canVerify,
              onPressed: () => _ctrl.verifyCode(code: _otpCtrl.text),
              busy: state.verifying,
              label: 'Verify',
            );
          },
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: state.busy ? null : () => _ctrl.resendLoginOtp(),
          child: const Text('Resend code'),
        ),
      ],
    );
  }

  Widget _emailEntryStep(LoginState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: state.busy
              ? null
              : () {
                  _emailOtpCtrl.clear();
                  _ctrl.backToPhone();
                },
          child: const Text('Back'),
        ),
        const SizedBox(height: 8),
        _textField(
          controller: _emailCtrl,
          enabled: !state.busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'name@company.com',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) {
            final email = _emailCtrl.text.trim();
            final can = _looksLikeEmail(email) && !state.busy;
            if (can) _ctrl.startEmailVerify(email: email);
          },
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _emailCtrl,
          builder: (context, value, _) {
            final email = value.text.trim();
            final canSend = _looksLikeEmail(email) && !state.busy;

            return _primaryButton(
              enabled: canSend,
              onPressed: () {
                // optional: keep controller state consistent with UI
                _ctrl.setPhoneNumber(_phoneCtrl.text);
                _ctrl.startEmailVerify(email: _emailCtrl.text);
              },

              busy: state.sending,
              label: 'Send email code',
            );
          },
        ),
      ],
    );
  }

  Widget _emailOtpStep(LoginState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: state.busy
              ? null
              : () {
                  _emailOtpCtrl.clear();
                  _ctrl.backToEmailEntry();
                },
          child: const Text('Back'),
        ),
        const SizedBox(height: 8),
        _textField(
          controller: _emailOtpCtrl,
          enabled: !state.busy,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            labelText: 'Enter 6-digit email code',
            border: OutlineInputBorder(),
            isDense: true,
            counterText: '',
          ),
          onSubmitted: (_) {
            final code = _emailOtpCtrl.text.trim();
            final can = code.length == 6 && !state.busy;
            if (can) _ctrl.verifyEmailCode(code: code);
          },
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _emailOtpCtrl,
          builder: (context, value, _) {
            final code = value.text.trim();
            final canVerify = code.length == 6 && !state.busy;

            return _primaryButton(
              enabled: canVerify,
              onPressed: () => _ctrl.verifyEmailCode(code: _emailOtpCtrl.text),
              busy: state.verifying,
              label: 'Verify email',
            );
          },
        ),
      ],
    );
  }

  Widget _nameStep(LoginState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: state.busy ? null : () => _ctrl.backToPhone(),
          child: const Text('Back'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _textField(
                controller: _firstNameCtrl,
                enabled: !state.busy,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'First name (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _textField(
                controller: _lastNameCtrl,
                enabled: !state.busy,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Last name (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Display name is required. We show the error when empty.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _displayNameCtrl,
          builder: (context, value, _) {
            final displayName = value.text.trim();
            final hasDisplayName = displayName.isNotEmpty;

            return _textField(
              controller: _displayNameCtrl,
              enabled: !state.busy,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Display name *',
                hintText: 'e.g. Dr. John Doe / Pharmacy Mpya',
                border: const OutlineInputBorder(),
                isDense: true,
                helperText: 'This is what others will see.',
                errorText: hasDisplayName ? null : 'Display name is required',
              ),
            );
          },
        ),

        const SizedBox(height: 10),
        _textField(
          controller: _companyCtrl,
          enabled: !state.busy,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Company (required for companies)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _tryFinish(state),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _displayNameCtrl,
          builder: (context, value, _) {
            final displayName = value.text.trim();
            final canFinish = displayName.isNotEmpty && !state.busy;

            return _primaryButton(
              enabled: canFinish,
              onPressed: () => _tryFinish(state),
              busy: state.savingProfile,
              label: 'Finish',
            );
          },
        ),
      ],
    );
  }

  void _tryFinish(LoginState state) {
    if (state.busy) return;

    final displayName = _displayNameCtrl.text.trim();
    if (displayName.isEmpty) return;

    _ctrl.finishOnboardingAfterName(
      firstName: _firstNameCtrl.text,
      lastName: _lastNameCtrl.text,
      displayName: _displayNameCtrl.text,
      companyName: _companyCtrl.text,
    );
  }
}

class _StepHint extends StatelessWidget {
  const _StepHint({required this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    final t = (text ?? '').trim();
    if (t.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Text(
      t,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.25),
    );
  }
}
