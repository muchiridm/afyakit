import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/users/controllers/login_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(loginControllerProvider.notifier);
    final state = ref.watch(loginControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FF),
      body: Center(child: _buildLoginCard(context, controller, state)),
    );
  }

  Widget _buildLoginCard(
    BuildContext context,
    LoginController controller,
    LoginFormState state,
  ) {
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
              // Brand header
              Column(
                children: [
                  // Placeholder for logo
                  Icon(
                    Icons.local_hospital,
                    size: 48,
                    color: Colors.deepPurple.shade700,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'DanabTMC',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Danab TMC',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTitle(),
              const SizedBox(height: 24),
              _buildEmailField(state),
              const SizedBox(height: 16),
              _buildPasswordField(controller),
              _buildForgotPasswordButton(context, controller),
              const SizedBox(height: 16),
              _buildLoginButton(context, controller, state),
            ],
          ),
        ),
      ),
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
      ),
    );
  }
}
