// lib/hq/auth/hq_login_screen.dart
import 'package:afyakit/hq/auth/hq_login_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HqLoginScreen extends ConsumerStatefulWidget {
  const HqLoginScreen({super.key});
  @override
  ConsumerState<HqLoginScreen> createState() => _HqLoginScreenState();
}

class _HqLoginScreenState extends ConsumerState<HqLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showPass = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    await ref
        .read(hqLoginControllerProvider.notifier)
        .signIn(email: _email.text.trim(), password: _password.text);
    // HqGate reacts via idTokenChanges → no navigation here.
  }

  Future<void> _resetPassword() async {
    await ref
        .read(hqLoginControllerProvider.notifier)
        .resetPassword(_email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hqLoginControllerProvider);
    final busy = state.isLoading;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 16),
                        _buildEmailField(busy),
                        const SizedBox(height: 12),
                        _buildPasswordField(busy),
                        const SizedBox(height: 8),
                        _buildResetButton(busy),
                        _buildErrorText(state.error),
                        const SizedBox(height: 8),
                        _buildSubmitButton(busy),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── sections ─────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(
      color: t.bodySmall?.color?.withOpacity(0.7),
    );
    return Column(
      children: [
        const CircleAvatar(radius: 22, child: Text('AH')),
        const SizedBox(height: 12),
        Text('AfyaKit HQ', style: t.headlineSmall),
        const SizedBox(height: 6),
        Text('Superadmin accounts only', style: muted),
      ],
    );
  }

  Widget _buildEmailField(bool busy) {
    return TextFormField(
      controller: _email,
      enabled: !busy,
      autofocus: true,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.username, AutofillHints.email],
      decoration: InputDecoration(
        labelText: 'Email Address',
        border: const OutlineInputBorder(),
        suffixIcon: (_email.text.isEmpty || busy)
            ? null
            : IconButton(
                tooltip: 'Clear',
                onPressed: () => setState(_email.clear),
                icon: const Icon(Icons.clear),
              ),
      ),
      onChanged: (_) => setState(() {}),
      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildPasswordField(bool busy) {
    return TextFormField(
      controller: _password,
      enabled: !busy,
      obscureText: !_showPass,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onEditingComplete: _submit,
      decoration: InputDecoration(
        labelText: 'Password',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _showPass ? 'Hide password' : 'Show password',
          onPressed: () => setState(() => _showPass = !_showPass),
          icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildResetButton(bool busy) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: busy ? null : _resetPassword,
        child: const Text('Reset password?'),
      ),
    );
  }

  Widget _buildErrorText(String? error) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: (error == null || error.isEmpty)
          ? const SizedBox.shrink()
          : Padding(
              key: const ValueKey('err'),
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
    );
  }

  Widget _buildSubmitButton(bool busy) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: busy ? null : _submit,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock),
        label: Text(busy ? 'Signing in…' : 'Login'),
      ),
    );
  }
}
