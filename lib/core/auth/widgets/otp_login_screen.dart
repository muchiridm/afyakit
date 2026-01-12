// lib/core/auth/widgets/otp_login_screen.dart

import 'package:afyakit/core/auth/controllers/login_controller.dart';
import 'package:afyakit/core/auth/models/otp_login_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OtpLoginScreen extends ConsumerStatefulWidget {
  const OtpLoginScreen({
    super.key,
    required this.copy,
    this.backgroundColor = const Color(0xFFFDF8FF),
  });

  final OtpLoginCopy copy;
  final Color backgroundColor;

  @override
  ConsumerState<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends ConsumerState<OtpLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  OtpChannel _channel = OtpChannel.email;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _listenForClose();

    final state = ref.watch(loginControllerProvider);

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: _buildAppBar(),
      body: SafeArea(child: _buildBody(state)),
    );
  }

  // ─────────────────────────────────────────────
  // Reactive side-effects (UI reacts to controller state)
  // ─────────────────────────────────────────────

  void _listenForClose() {
    ref.listen<LoginState>(loginControllerProvider, (prev, next) {
      if (next.closeScreen) {
        Navigator.of(context).maybePop();
      }
    });
  }

  // ─────────────────────────────────────────────
  // Actions (dumb UI delegates)
  // ─────────────────────────────────────────────

  void _close() {
    ref.read(loginControllerProvider.notifier).reset();
    Navigator.of(context).maybePop();
  }

  void _send() {
    ref
        .read(loginControllerProvider.notifier)
        .sendCode(
          phoneE164: _phoneCtrl.text,
          email: _channel == OtpChannel.email ? _emailCtrl.text : null,
          channel: _channel,
        );
  }

  void _verify() {
    ref
        .read(loginControllerProvider.notifier)
        .verifyCode(
          phoneE164: _phoneCtrl.text,
          code: _codeCtrl.text,
          email: _channel == OtpChannel.email ? _emailCtrl.text : null,
          channel: _channel,
        );
  }

  void _onChannelChanged(Set<OtpChannel> selection) {
    setState(() {
      _channel = selection.first;
      _codeCtrl.clear();
    });
    ref.read(loginControllerProvider.notifier).reset();
  }

  // ─────────────────────────────────────────────
  // UI builders (pure)
  // ─────────────────────────────────────────────

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

  Widget _buildBody(LoginState state) {
    return LayoutBuilder(
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _buildChannelSelector(),
                  const SizedBox(height: 24),
                  _buildPhoneField(state),
                  const SizedBox(height: 12),
                  if (_channel == OtpChannel.email) _buildEmailField(state),
                  const SizedBox(height: 12),
                  _buildSendButton(state),
                  _buildCodeSection(state),
                ],
              ),
            ),
          ),
        );
      },
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

  Widget _buildChannelSelector() {
    return SegmentedButton<OtpChannel>(
      segments: const [
        ButtonSegment<OtpChannel>(
          value: OtpChannel.email,
          label: Text('Email'),
          icon: Icon(Icons.email),
        ),
      ],
      selected: {_channel},
      onSelectionChanged: _onChannelChanged,
    );
  }

  Widget _buildPhoneField(LoginState state) {
    return TextField(
      controller: _phoneCtrl,
      enabled: !state.codeSent,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        labelText: 'Phone number (E.164)',
        hintText: '+2547...',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildEmailField(LoginState state) {
    return TextField(
      controller: _emailCtrl,
      enabled: !state.codeSent,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'Email address',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildSendButton(LoginState state) {
    if (state.codeSent) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: state.sending ? null : _send,
        child: state.sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Send code'),
      ),
    );
  }

  Widget _buildCodeSection(LoginState state) {
    if (!state.codeSent) return const SizedBox.shrink();

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
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.verifying ? null : _verify,
            child: state.verifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify & sign in'),
          ),
        ),
      ],
    );
  }
}
