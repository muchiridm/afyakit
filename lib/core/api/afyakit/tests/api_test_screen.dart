// lib/core/api/afyakit/tests/api_test_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_test_controller.dart';

class ApiTestScreen extends ConsumerStatefulWidget {
  const ApiTestScreen({super.key});

  @override
  ConsumerState<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends ConsumerState<ApiTestScreen> {
  bool _checkingAuth = false;
  String _authResult = '';

  Future<void> _checkFirebaseSession() async {
    setState(() {
      _checkingAuth = true;
      _authResult = 'Checking Firebase Authentication...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw StateError('Not signed in to Firebase Authentication');
      }

      // Refresh the ID token without printing or exposing it.
      final result = await user.getIdTokenResult(true);

      final adminClaim = result.claims?['tenant_admin_tenants'];
      final adminTenants = adminClaim is List
          ? adminClaim.map((e) => e.toString()).toList()
          : <String>[];

      final authenticatedAt = result.authTime;
      final expiresAt = result.expirationTime;

      final recentlyAuthenticated =
          authenticatedAt != null &&
          DateTime.now().difference(authenticatedAt).inSeconds >= 0 &&
          DateTime.now().difference(authenticatedAt).inSeconds <= 300;

      if (!mounted) return;

      setState(() {
        _authResult = [
          'Firebase Authentication',
          '-------------------------',
          'Signed in: Yes',
          'UID: ${user.uid}',
          'Project: ${Firebase.app().options.projectId}',
          'Token expires: ${expiresAt?.toLocal()}',
          'Last authentication: ${authenticatedAt?.toLocal()}',
          'Recently authenticated (5 min): $recentlyAuthenticated',
          'Tenant-admin tenants: ${adminTenants.join(', ')}',
          'Admin for afya: ${adminTenants.contains('afya')}',
          '',
          'ID token: Hidden',
          'Refresh token: Hidden',
          '',
          'Note: Refreshing a token does not reset auth_time.',
          'Permanent deletion still requires independent',
          'retention clearance and backend authorisation.',
        ].join('\n');
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _authResult = 'Authentication check failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _checkingAuth = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(apiTestControllerProvider);
    final ctrl = ref.read(apiTestControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('API Tester')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Item ID (or docId)',
                      hintText: 'e.g. 584f89db-… or firestore doc id',
                    ),
                    onChanged: ctrl.setItemId,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: state.loading ? null : ctrl.runTests,
                          child: const Text('Run Tests'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: state.loading
                              ? null
                              : ctrl.searchItemAcrossTypes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                          ),
                          child: const Text('Search Item Across Types'),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Batch ID',
                      hintText: 'e.g. PIaGhrg9ndeSKxfHuVGR',
                    ),
                    onChanged: ctrl.setBatchId,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: state.loading ? null : ctrl.searchBatchId,
                      icon: const Icon(Icons.vpn_key),
                      label: const Text('Search Batch'),
                    ),
                  ),
                  const Divider(height: 24),

                  // Firebase Authentication diagnostics.
                  Text(
                    'Firebase Authentication',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _checkingAuth ? null : _checkFirebaseSession,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Check Firebase Session'),
                    ),
                  ),
                  if (_checkingAuth) const LinearProgressIndicator(),
                  if (_authResult.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SelectableText(
                        _authResult,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  const Divider(height: 24),

                  Text(
                    'API Test Log',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (state.loading) const LinearProgressIndicator(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      state.logLines.join('\n'),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
