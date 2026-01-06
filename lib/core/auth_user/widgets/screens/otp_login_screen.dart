// lib/core/auth_user/widgets/screens/otp_login_screen.dart

import 'package:afyakit/core/auth/controllers/login_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reusable OTP login screen.
///
/// - Uses [loginControllerProvider] for all auth logic.
/// - Collects phone + email (for email OTP) + 6-digit code.
/// - Does NOT perform any navigation or tenant-specific routing.
///   Gates like AuthGate / HqGate should react to auth state externally.
class OtpLoginScreen extends ConsumerStatefulWidget {
  const OtpLoginScreen({
    super.key,
    required this.appTitle,
    this.headerTitle,
    this.headerSubtitle = 'Sign in with Email OTP',
    this.description = 'We will email you a one-time login code.',
    this.backgroundColor = const Color(0xFFFDF8FF),
  });

  /// Title shown in the AppBar.
  final String appTitle;

  /// Big header title above the form.
  /// Defaults to [appTitle] if null.
  final String? headerTitle;

  /// Subtitle under the header title.
  final String headerSubtitle;

  /// Short helper description below the subtitle.
  final String description;

  /// Scaffold background color.
  final Color backgroundColor;

  @override
  ConsumerState<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends ConsumerState<OtpLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  // Email-only OTP for now
  OtpChannel _channel = OtpChannel.email;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final controller = ref.read(loginControllerProvider.notifier);

    await controller.sendCode(
      phoneE164: _phoneCtrl.text,
      email: _channel == OtpChannel.email ? _emailCtrl.text : null,
      channel: _channel,
    );

    // If auth gating/navigating happens, this widget may already be gone.
    if (!mounted) return;
    // (Nothing else to do here currently.)
  }

  Future<void> _verifyCode() async {
    final controller = ref.read(loginControllerProvider.notifier);

    final ok = await controller.verifyCode(
      phoneE164: _phoneCtrl.text,
      code: _codeCtrl.text,
      email: _channel == OtpChannel.email ? _emailCtrl.text : null,
      channel: _channel,
    );

    // Gate may have already replaced this screen.
    if (!mounted) return;

    if (!ok) return;

    // ✅ clear visible login UI state (even if gate takes over)
    _codeCtrl.clear();
    FocusScope.of(context).unfocus();

    // Optional: also clear phone/email if you prefer
    // _phoneCtrl.clear();
    // _emailCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final loginState = ref.watch(loginControllerProvider);

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(title: Text(widget.appTitle), centerTitle: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    // so the card can still center and have room to breathe,
                    // but will scroll if it overflows the viewport
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(primary),
                      const SizedBox(height: 24),
                      _buildChannelSelector(),
                      const SizedBox(height: 24),
                      _buildPhoneField(codeSent: loginState.codeSent),
                      const SizedBox(height: 12),
                      if (_channel == OtpChannel.email)
                        _buildEmailField(codeSent: loginState.codeSent),
                      const SizedBox(height: 12),
                      _buildSendButton(
                        sending: loginState.sending,
                        codeSent: loginState.codeSent,
                      ),
                      _buildCodeSection(
                        codeSent: loginState.codeSent,
                        verifying: loginState.verifying,
                      ),
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

  // ─────────────────────────────────────────────
  // Private UI builders
  // ─────────────────────────────────────────────

  Widget _buildHeader(Color primary) {
    final headerTitle = widget.headerTitle ?? widget.appTitle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headerTitle,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          widget.headerSubtitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: primary.withOpacity(0.85),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(widget.description, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildChannelSelector() {
    return SegmentedButton<OtpChannel>(
      segments: const [
        ButtonSegment<OtpChannel>(
          value: OtpChannel.email,
          label: Text('Email'),
          icon: Icon(Icons.email_outlined),
        ),
      ],
      selected: {_channel},
      onSelectionChanged: (selection) {
        if (!mounted) return;

        setState(() {
          _channel = selection.first;
          _codeCtrl.clear();
        });

        // Reset attempt state in controller when channel changes
        ref.read(loginControllerProvider.notifier).resetAttempt();
      },
    );
  }

  Widget _buildPhoneField({required bool codeSent}) {
    return TextField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        labelText: 'Phone number (E.164)',
        hintText: '+2547...',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      enabled: !codeSent,
    );
  }

  Widget _buildEmailField({required bool codeSent}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          enabled: !codeSent,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSendButton({required bool sending, required bool codeSent}) {
    if (codeSent) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: sending ? null : _sendCode,
        child: sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Send code'),
      ),
    );
  }

  Widget _buildCodeSection({required bool codeSent, required bool verifying}) {
    if (!codeSent) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Enter 6-digit code',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _verifyCode(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: verifying ? null : _verifyCode,
            child: verifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verify & sign in'),
          ),
        ),
      ],
    );
  }
}
