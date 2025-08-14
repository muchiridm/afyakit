import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/users/controllers/login_controller.dart';
import 'package:afyakit/shared/providers/tenant_config_provider.dart';

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
    final logoAsset = cfg.logoAsset;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FF),
      body: Center(
        child: _buildLoginCard(
          context: context,
          controller: controller,
          state: state,
          displayName: displayName,
          logoAsset: logoAsset,
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
    required String logoAsset,
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
                logoAsset: logoAsset,
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
    required String logoAsset,
    required Color primary,
  }) {
    return Column(
      children: [
        // Prefer tenant logo if provided, fallback to icon
        if (logoAsset.isNotEmpty)
          Image.asset(
            logoAsset,
            height: 48,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.local_hospital, size: 48, color: primary),
          )
        else
          Icon(Icons.local_hospital, size: 48, color: primary),
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
        Text(
          displayName, // subtitle/tagline; swap if you want a different strapline
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
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
