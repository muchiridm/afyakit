import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/native_contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/auth/auth_user/controllers/profile_controller.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/user_status_x.dart';
import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';

/// Compatibility entry point. Self -> Native Contact, target user -> access administration.
class UserProfileEditorScreen extends ConsumerWidget {
  const UserProfileEditorScreen({super.key, this.user});
  final AuthUser? user;
  @override
  Widget build(BuildContext context, WidgetRef ref) => user == null
      ? const _MyContactEditor()
      : _AccountAdministration(target: user!);
}

class _MyContactEditor extends ConsumerStatefulWidget {
  const _MyContactEditor();
  @override
  ConsumerState<_MyContactEditor> createState() => _MyContactEditorState();
}

class _MyContactEditorState extends ConsumerState<_MyContactEditor> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _idNumber = TextEditingController();
  NativeContact? _contact;
  bool _initialised = false;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final service = await ref.read(nativeContactsServiceProvider.future);
      final contact = await service.getMine();
      if (!mounted) return;
      setState(() {
        _contact = contact;
        _name.text = contact.displayName;
        _phone.text = contact.phone ?? '';
        _mobile.text = contact.mobile ?? '';
        _email.text = contact.email ?? '';
        _idNumber.text = contact.idNumber ?? '';
        _initialised = true;
        _error = null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _initialised = true;
        _error = err.toString();
      });
    }
  }

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      final service = await ref.read(nativeContactsServiceProvider.future);
      final updated = await service.updateMine({
        'display_name': _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'mobile': _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'id_number': _idNumber.text.trim().isEmpty
            ? null
            : _idNumber.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _contact = updated;
        _error = null;
      });
      await ref
          .read(sessionControllerProvider(ref.read(tenantIdProvider)).notifier)
          .refresh(forceNetwork: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contact updated')));
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _mobile, _email, _idNumber]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    maxWidth: 720,
    scrollable: true,
    header: const AppHeader(title: 'My Native Contact'),
    body: !_initialised
        ? const Center(child: CircularProgressIndicator())
        : _contact == null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Contact not available'),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _key,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Account number: ${_contact!.accountNumber ?? _contact!.id}',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Name required' : null,
                  ),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact phone (not a verified login number)',
                    ),
                  ),
                  TextFormField(
                    controller: _mobile,
                    decoration: const InputDecoration(
                      labelText: 'Mobile (unverified)',
                    ),
                  ),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'General email (unverified)',
                    ),
                  ),
                  TextFormField(
                    controller: _idNumber,
                    decoration: const InputDecoration(
                      labelText: 'Identification number',
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save contact'),
                  ),
                ],
              ),
            ),
          ),
  );
}

class _AccountAdministration extends ConsumerStatefulWidget {
  const _AccountAdministration({required this.target});
  final AuthUser target;
  @override
  ConsumerState<_AccountAdministration> createState() =>
      _AccountAdministrationState();
}

class _AccountAdministrationState
    extends ConsumerState<_AccountAdministration> {
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          ref.read(profileControllerProvider(widget.target).notifier).init();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider(widget.target));
    final ctrl = ref.read(profileControllerProvider(widget.target).notifier);
    final u = state.user;
    return AppPage(
      maxWidth: 720,
      scrollable: true,
      header: const AppHeader(title: 'User administration'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.loading && u == null
            ? const Center(child: CircularProgressIndicator())
            : u == null
            ? const Text('User unavailable')
            : !state.isAdminEditing
            ? const Text('You are not authorised to administer this account.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('UID: ${u.uid}'),
                  Text('Account: ${u.accountNumber ?? '—'}'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserStatus>(
                    initialValue: state.statusOverride ?? u.status,
                    items: UserStatus.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) ctrl.setStatus(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('App-specific staff roles'),
                  Wrap(
                    spacing: 8,
                    children: StaffRole.values
                        .map(
                          (role) => FilterChip(
                            label: Text(role.label),
                            selected: (state.staffRoleOverrides ?? u.staffRoles)
                                .contains(role),
                            onSelected: (_) => ctrl.toggleStaffRole(role),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: state.loading ? null : () => ctrl.save(context),
                    child: const Text('Save account access'),
                  ),
                ],
              ),
      ),
    );
  }
}
