import 'package:afyakit/features/hq/users/all_users/all_users_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Returns true only after application-scoped email verification succeeds.
Future<bool> showAppEmailChangeDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String tenantId,
  required String appId,
  required String uid,
  String? currentEmail,
}) async {
  final cleanAppId = appId.trim().toLowerCase();
  if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(cleanAppId)) {
    throw ArgumentError.value(appId, 'appId', 'Invalid application ID');
  }
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AppEmailChangeDialog(
      ref: ref,
      tenantId: tenantId,
      appId: cleanAppId,
      uid: uid,
      currentEmail: currentEmail,
    ),
  );
  return result ?? false;
}

class _AppEmailChangeDialog extends StatefulWidget {
  const _AppEmailChangeDialog({
    required this.ref,
    required this.tenantId,
    required this.appId,
    required this.uid,
    this.currentEmail,
  });
  final WidgetRef ref;
  final String tenantId;
  final String appId;
  final String uid;
  final String? currentEmail;
  @override
  State<_AppEmailChangeDialog> createState() => _AppEmailChangeDialogState();
}

class _AppEmailChangeDialogState extends State<_AppEmailChangeDialog> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  String? _attemptId;
  String? _error;
  bool _busy = false;
  bool _closing = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _closing) return;
    final email = _emailController.text.trim().toLowerCase();
    final code = _codeController.text.trim();
    final verifying = _attemptId != null;
    if (!verifying &&
        (email.length > 254 ||
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (!verifying && email == widget.currentEmail?.trim().toLowerCase()) {
      setState(() => _error = 'This is already the current email.');
      return;
    }
    if (verifying && !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the six-digit verification code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = await widget.ref.read(allUsersServiceProvider.future);
      if (!verifying) {
        final attemptId = await service.startTenantEmailChange(
          tenantId: widget.tenantId,
          appId: widget.appId,
          uid: widget.uid,
          email: email,
        );
        if (!mounted) return;
        setState(() => _attemptId = attemptId);
      } else {
        await service.verifyTenantEmailChange(
          tenantId: widget.tenantId,
          appId: widget.appId,
          uid: widget.uid,
          attemptId: _attemptId!,
          code: code,
        );
        if (!mounted) return;
        _closing = true;
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted || _closing) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && !_closing) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verifying = _attemptId != null;
    final hasEmail = (widget.currentEmail ?? '').trim().isNotEmpty;
    return AlertDialog(
      title: Text(
        verifying
            ? 'Verify application email'
            : hasEmail
            ? 'Change application email'
            : 'Add application email',
      ),
      content: SizedBox(
        width: 370,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tenant: ${widget.tenantId}'),
              Text('Application: ${widget.appId}'),
              if (hasEmail) Text('Current: ${widget.currentEmail}'),
              const SizedBox(height: 16),
              if (!verifying)
                TextField(
                  controller: _emailController,
                  enabled: !_busy,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    border: OutlineInputBorder(),
                  ),
                )
              else ...[
                Text('Enter the code sent to ${_emailController.text.trim()}.'),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  enabled: !_busy,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy
                ? 'Please wait…'
                : verifying
                ? 'Verify and save'
                : 'Send code',
          ),
        ),
      ],
    );
  }
}
