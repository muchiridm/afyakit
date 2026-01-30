// lib/core/auth/widgets/login_screen.dart
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
  final _companyCtrl = TextEditingController();

  ProviderSubscription<LoginState>? _sub;

  @override
  void initState() {
    super.initState();

    _sub = ref.listenManual<LoginState>(loginControllerProvider, (prev, next) {
      // ✅ UX polish: clear irrelevant fields when step changes
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
            // don’t clear name fields here; user may be returning / partially complete
            break;
        }
      }

      // ✅ Close screen when controller says done
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
    _companyCtrl.dispose();

    super.dispose();
  }

  LoginController get _ctrl => ref.read(loginControllerProvider.notifier);

  void _close() {
    _ctrl.reset();
    Navigator.of(context).maybePop(false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);

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
                      _buildHeader(context),
                      const SizedBox(height: 24),

                      // ✅ Dumb UI: render purely based on step
                      switch (state.step) {
                        LoginStep.phone => _phoneStep(state),
                        LoginStep.otp => _otpStep(state),
                        LoginStep.emailEntry => _emailEntryStep(state),
                        LoginStep.emailOtp => _emailOtpStep(state),
                        LoginStep.nameEntry => _nameStep(state),
                      },
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

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
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

  Widget _phoneStep(LoginState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.stepHint ?? 'Enter your phone number to continue.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          enabled: !state.busy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+2547...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _ctrl.sendCode(phoneE164: _phoneCtrl.text),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.busy
                ? null
                : () => _ctrl.sendCode(phoneE164: _phoneCtrl.text),
            child: state.sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _otpStep(LoginState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.stepHint ?? 'Enter the 6-digit code.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
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
        TextField(
          controller: _otpCtrl,
          enabled: !state.busy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            labelText: 'Enter 6-digit code',
            border: OutlineInputBorder(),
            isDense: true,
            counterText: '',
          ),
          onSubmitted: (_) => _ctrl.verifyCode(code: _otpCtrl.text),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.busy
                ? null
                : () => _ctrl.verifyCode(code: _otpCtrl.text),
            child: state.verifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.busy
              ? null
              : () async {
                  _otpCtrl.clear();
                  await _ctrl.resendLoginOtp();
                  await _ctrl.sendCode(phoneE164: _phoneCtrl.text);
                },
          child: const Text('Resend code'),
        ),
      ],
    );
  }

  Widget _emailEntryStep(LoginState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.stepHint ??
              'Add your email to finish setup.\nWe’ll send a 6-digit code to confirm it.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.busy
              ? null
              : () {
                  _emailCtrl.clear();
                  _emailOtpCtrl.clear();
                  _ctrl.backToPhone();
                },
          child: const Text('Back'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          enabled: !state.busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'name@company.com',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _ctrl.startEmailVerify(email: _emailCtrl.text),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.busy
                ? null
                : () => _ctrl.startEmailVerify(email: _emailCtrl.text),
            child: state.sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send email code'),
          ),
        ),
      ],
    );
  }

  Widget _emailOtpStep(LoginState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.stepHint ?? 'Enter the email code.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
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
        TextField(
          controller: _emailOtpCtrl,
          enabled: !state.busy,
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
          onSubmitted: (_) => _ctrl.verifyEmailCode(code: _emailOtpCtrl.text),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.busy
                ? null
                : () => _ctrl.verifyEmailCode(code: _emailOtpCtrl.text),
            child: state.verifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify email'),
          ),
        ),
      ],
    );
  }

  Widget _nameStep(LoginState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.stepHint ?? 'Add your name to finish setup.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.busy
              ? null
              : () {
                  _ctrl.backToPhone();
                },
          child: const Text('Back'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _firstNameCtrl,
          enabled: !state.busy,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'First name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _lastNameCtrl,
          enabled: !state.busy,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Last name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _companyCtrl,
          enabled: !state.busy,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Company (optional)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _ctrl.finishOnboardingAfterName(
            firstName: _firstNameCtrl.text,
            lastName: _lastNameCtrl.text,
            companyName: _companyCtrl.text,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.busy
                ? null
                : () => _ctrl.finishOnboardingAfterName(
                    firstName: _firstNameCtrl.text,
                    lastName: _lastNameCtrl.text,
                    companyName: _companyCtrl.text,
                  ),
            child: state.savingProfile
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Finish'),
          ),
        ),
      ],
    );
  }
}
