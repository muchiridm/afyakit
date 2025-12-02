// lib/core/auth_users/widgets/screens/login_screen.dart

import 'package:afyakit/core/auth_users/controllers/login_controller.dart';
import 'package:afyakit/core/auth_users/widgets/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  OtpChannel _channel = OtpChannel.wa;

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
  }

  Future<void> _verifyCode() async {
    final controller = ref.read(loginControllerProvider.notifier);

    final success = await controller.verifyCode(
      phoneE164: _phoneCtrl.text,
      code: _codeCtrl.text,
      email: _channel == OtpChannel.email ? _emailCtrl.text : null,
      channel: _channel,
    );

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final loginState = ref.watch(loginControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FF),
      appBar: AppBar(title: const Text('Sign in'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Private UI builders
  // ─────────────────────────────────────────────

  Widget _buildHeader(Color primary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sign in with OTP',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose how to receive your login code.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildChannelSelector() {
    return SegmentedButton<OtpChannel>(
      segments: const [
        ButtonSegment<OtpChannel>(
          value: OtpChannel.wa,
          label: Text('WhatsApp'),
          icon: Icon(Icons.chat_bubble_outline),
        ),
        ButtonSegment<OtpChannel>(
          value: OtpChannel.sms,
          label: Text('SMS'),
          icon: Icon(Icons.sms),
        ),
        ButtonSegment<OtpChannel>(
          value: OtpChannel.email,
          label: Text('Email'),
          icon: Icon(Icons.email_outlined),
        ),
      ],
      selected: {_channel},
      onSelectionChanged: (selection) {
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
