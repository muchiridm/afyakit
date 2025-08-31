// lib/core/auth_users/screens/login_screen.dart

import 'package:afyakit/hq/core/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/auth_users/user_operations/controllers/login_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Controllers/state
    final controller = ref.watch(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);

    // Per-tenant config
    final cfg = ref.watch(tenantConfigProvider);
    final displayName = cfg.displayName;
    final logoPath = cfg.logoPath; // String? now
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FF),
      // allow body to move when keyboard shows
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 16 + bottomInset),
              child: ConstrainedBox(
                // ensures centering when there’s plenty of height,
                // but allows scrolling when there isn’t
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _buildLoginCard(
                      context: context,
                      controller: controller,
                      state: state,
                      displayName: displayName,
                      logoPath: logoPath,
                      primary: primary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Private builders
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildLoginCard({
    required BuildContext context,
    required LoginController controller,
    required LoginFormState state,
    required String displayName,
    required String? logoPath,
    required Color primary,
  }) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          // shrink to content; lets the outer scroll view handle small screens
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBrandHeader(
              displayName: displayName,
              logoPath: logoPath,
              primary: primary,
            ),
            const SizedBox(height: 20),
            _buildTitle(),
            const SizedBox(height: 20),
            _buildEmailField(state),
            const SizedBox(height: 12),
            _buildPasswordField(controller),
            _buildForgotPasswordButton(context, controller),
            const SizedBox(height: 16),
            _buildLoginButton(context, controller, state, primary),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader({
    required String displayName,
    required String? logoPath,
    required Color primary,
  }) {
    final radius = BorderRadius.circular(8.0);
    final hasLogo = logoPath != null && logoPath.trim().isNotEmpty;

    Widget logo() {
      if (!hasLogo) {
        return _initialsBlock(
          displayName: displayName,
          primary: primary,
          radius: radius,
        );
      }

      final path = logoPath.trim();
      final isNetwork =
          path.startsWith('http://') || path.startsWith('https://');

      final image = isNetwork
          ? Image.network(
              path,
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.local_hospital, size: 48, color: primary),
            )
          : Image.asset(
              path,
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.local_hospital, size: 48, color: primary),
            );

      return ClipRRect(borderRadius: radius, child: image);
    }

    return Column(
      children: [
        logo(),
        const SizedBox(height: 8),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Welcome back',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _initialsBlock({
    required String displayName,
    required Color primary,
    required BorderRadius radius,
  }) {
    final initials = _initials(displayName);
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary.withOpacity(0.12),
        borderRadius: radius,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _buildTitle() {
    return const Text(
      'Sign in with Email',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildEmailField(LoginFormState state) {
    return TextField(
      controller: state.emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Email Address',
        border: OutlineInputBorder(),
        hintText: 'e.g. user@example.com',
        isDense: true,
      ),
    );
  }

  Widget _buildPasswordField(LoginController controller) {
    return TextField(
      obscureText: true,
      onSubmitted: (_) => controller.login(),
      decoration: const InputDecoration(
        labelText: 'Password',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: controller.setPassword,
    );
  }

  Widget _buildForgotPasswordButton(
    BuildContext context,
    LoginController controller,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () async {
          FocusScope.of(context).unfocus();
          await controller.sendPasswordReset();
        },
        child: const Text('Reset password?'),
      ),
    );
  }

  Widget _buildLoginButton(
    BuildContext context,
    LoginController controller,
    LoginFormState state,
    Color primary,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: state.loading
            ? null
            : () async {
                FocusScope.of(context).unfocus();
                await controller.login();
              },
        icon: state.loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.lock_open),
        label: const Text('Login'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
