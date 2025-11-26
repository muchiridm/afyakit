// lib/core/auth_users/widgets/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth_users/utils/user_format.dart';

import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/hq/tenants/providers/tenant_logo_providers.dart';
import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';

import 'package:afyakit/core/auth_users/controllers/login/login_controller.dart';
import 'package:afyakit/core/auth_users/controllers/auth_session/session_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantSlug = ref.watch(tenantSlugProvider);

    // listen for "login attempt finished" → refresh session
    ref.listen<LoginFormState>(loginControllerProvider, (prev, next) {
      final wasLoading = prev?.loading == true;
      final nowIdle = next.loading == false;

      if (wasLoading && nowIdle) {
        // attempt completed (success or failure) → ask session to re-check
        ref.read(sessionControllerProvider(tenantSlug).notifier).ensureReady();
      }
    });

    return _buildScaffold(context, ref);
  }

  Widget _buildScaffold(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(tenantProfileProvider);
    final logoUrl = ref.watch(tenantSecondaryLogoUrlProvider);
    final displayName = profile.displayName;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FF),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 16 + bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _buildContentCard(
                        context: context,
                        ref: ref,
                        displayName: displayName,
                        logoUrl: logoUrl,
                        primary: primary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContentCard({
    required BuildContext context,
    required WidgetRef ref,
    required String displayName,
    required String? logoUrl,
    required Color primary,
  }) {
    final loginCtrl = ref.watch(loginControllerProvider.notifier);
    final loginState = ref.watch(loginControllerProvider);

    // Responsive logo size – bigger on wider screens
    final screenWidth = MediaQuery.of(context).size.width;
    final double logoSize = screenWidth < 480 ? 120.0 : 160.0;

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBrandHeader(
              displayName: displayName,
              logoUrl: logoUrl,
              primary: primary,
              logoSize: logoSize,
            ),
            const SizedBox(height: 20),
            const TabBar(
              tabs: [
                Tab(text: 'Email'),
                Tab(text: 'WhatsApp'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: TabBarView(
                children: [
                  _buildEmailTab(context, loginCtrl, loginState, primary),
                  _buildWhatsAppTab(
                    sending: loginState.waSending,
                    verifying: loginState.waVerifying,
                    codeSent: loginState.waCodeSent,
                    onSendCode: (phone) => loginCtrl.sendWaCode(phone),
                    onVerify: (code) => loginCtrl.verifyWaCode(code),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader({
    required String displayName,
    required String? logoUrl,
    required Color primary,
    required double logoSize,
  }) {
    final radius = BorderRadius.circular(12.0);
    final hasLogo = logoUrl != null && logoUrl.trim().isNotEmpty;

    Widget logo() {
      if (!hasLogo) {
        // fallback: big initials block
        return _initialsBlock(
          displayName: displayName,
          primary: primary,
          radius: radius,
          size: logoSize,
        );
      }

      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          logoUrl,
          height: logoSize,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.local_hospital, size: logoSize, color: primary),
        ),
      );
    }

    return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: logo());
  }

  Widget _initialsBlock({
    required String displayName,
    required Color primary,
    required BorderRadius radius,
    double size = 150.0,
  }) {
    final initials = initialsFromName(displayName);
    return Container(
      width: size,
      height: size,
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
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  // Email Tab
  Widget _buildEmailTab(
    BuildContext context,
    LoginController controller,
    LoginFormState state,
    Color primary,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Sign in with Email',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: state.loginController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            border: OutlineInputBorder(),
            hintText: 'e.g. user@example.com',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          obscureText: true,
          onSubmitted: (_) => controller.login(),
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: controller.setPassword,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              FocusScope.of(context).unfocus();
              await controller.sendPasswordReset();
            },
            child: const Text('Reset password?'),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
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
        ),
      ],
    );
  }

  // WhatsApp Tab
  Widget _buildWhatsAppTab({
    required bool sending,
    required bool verifying,
    required bool codeSent,
    required ValueChanged<String> onSendCode,
    required ValueChanged<String> onVerify,
  }) {
    return _WhatsAppLoginTab(
      sending: sending,
      verifying: verifying,
      codeSent: codeSent,
      onSendCode: onSendCode,
      onVerify: onVerify,
    );
  }
}

class _WhatsAppLoginTab extends StatefulWidget {
  final bool sending;
  final bool verifying;
  final bool codeSent;
  final ValueChanged<String> onSendCode;
  final ValueChanged<String> onVerify;

  const _WhatsAppLoginTab({
    required this.sending,
    required this.verifying,
    required this.codeSent,
    required this.onSendCode,
    required this.onVerify,
  });

  @override
  State<_WhatsAppLoginTab> createState() => _WhatsAppLoginTabState();
}

class _WhatsAppLoginTabState extends State<_WhatsAppLoginTab> {
  final _phone = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.codeSent) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sign in with WhatsApp',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp number (E.164)',
              hintText: '+2547...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.sending
                  ? null
                  : () => widget.onSendCode(_phone.text),
              child: widget.sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send WhatsApp code'),
            ),
          ),
        ],
      );
    }

    // Code entry
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Enter the 6-digit code from WhatsApp',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '6-digit code',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => widget.onVerify(_code.text),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.verifying
                ? null
                : () => widget.onVerify(_code.text),
            child: widget.verifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verify & Sign in'),
          ),
        ),
      ],
    );
  }
}
