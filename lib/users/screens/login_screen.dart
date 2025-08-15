import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/users/controllers/login_controller.dart';
import 'package:afyakit/tenants/providers/tenant_config_provider.dart';

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
      body: Center(
        child: _buildLoginCard(
          context: context,
          controller: controller,
          state: state,
          displayName: displayName,
          logoPath: logoPath, // ← rename + allow null
          primary: primary,
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
    required String? logoPath, // ← allow null
    required Color primary,
  }) {
    return Card(
      margin: const EdgeInsets.all(32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBrandHeader(
                displayName: displayName,
                logoPath: logoPath, // ← pass through
                primary: primary,
              ),
              const SizedBox(height: 24),
              _buildTitle(),
              const SizedBox(height: 24),
              _buildEmailField(state),
              const SizedBox(height: 16),
              _buildPasswordField(controller),
              _buildForgotPasswordButton(context, controller),
              const SizedBox(height: 16),
              _buildLoginButton(context, controller, state, primary),
            ],
          ),
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
      decoration: const InputDecoration(
        labelText: 'Email Address',
        border: OutlineInputBorder(),
        hintText: 'e.g. user@example.com',
      ),
    );
  }

  Widget _buildPasswordField(LoginController controller) {
    return TextField(
      obscureText: true,
      decoration: const InputDecoration(
        labelText: 'Password',
        border: OutlineInputBorder(),
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
