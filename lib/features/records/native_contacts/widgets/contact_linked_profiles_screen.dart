import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/profiles_service.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_form_dialog.dart';
import '../native_contact.dart';
import '../native_contacts_controller.dart';

/// Staff-only UI. The API independently enforces app-scoped staff access.
class ContactLinkedProfilesScreen extends ConsumerStatefulWidget {
  const ContactLinkedProfilesScreen({super.key, required this.contact});
  final NativeContact contact;
  @override
  ConsumerState<ContactLinkedProfilesScreen> createState() =>
      _ContactLinkedProfilesScreenState();
}

class _ContactLinkedProfilesScreenState
    extends ConsumerState<ContactLinkedProfilesScreen> {
  String get account => widget.contact.accountNumber;
  Future<void> _edit({Profile? existing}) async {
    if (widget.contact.status != 'active') return;
    final value =
        await showDialog<
          ({String id, ProfileContactRelationship relationship})
        >(
          context: context,
          builder: (_) => _LinkProfileDialog(
            entityType: widget.contact.entityType,
            existing: existing,
          ),
        );
    if (value == null || !mounted) return;
    final ctrl = ref.read(nativeContactsControllerProvider.notifier);
    final ok = existing == null
        ? await ctrl.linkProfile(
            accountNumber: account,
            profileId: value.id,
            relationship: value.relationship,
          )
        : await ctrl.changeProfileLink(
            accountNumber: account,
            profileId: value.id,
            relationship: value.relationship,
          );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(contactLinkedProfilesProvider(account));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(nativeContactsControllerProvider).error ??
                'Could not save relationship',
          ),
        ),
      );
    }
  }

  /// Create a new patient record with the current Native Contact selected.
  /// The backend validates and persists the Contact link as part of creation.
  Future<void> _createLinkedProfile() async {
    if (widget.contact.status != 'active') return;
    final input = await showDialog<ProfileUpsertInput>(
      context: context,
      builder: (_) => ProfileFormDialog(
        allowExplicitContactLink: true,
        initialContact: widget.contact,
        initialRelationship: widget.contact.entityType == 'organization'
            ? ProfileContactRelationship.insurance
            : ProfileContactRelationship.self,
      ),
    );
    if (input == null || !mounted) return;
    if (input.accountNumber != account) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected Contact changed. No profile was created.'),
        ),
      );
      return;
    }
    try {
      await ref.read(profilesServiceProvider).create(input);
      if (!mounted) return;
      ref.invalidate(contactLinkedProfilesProvider(account));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health Profile created and linked')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to create linked Health Profile: $error'),
        ),
      );
    }
  }

  Future<void> _unlink(Profile p) async {
    if (widget.contact.status != 'active') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate association?'),
        content: Text(
          'Unlink ${p.fullName} from ${widget.contact.displayName}? Neither record is deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(nativeContactsControllerProvider.notifier)
        .unlinkProfile(accountNumber: account, profileId: p.profileId);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(contactLinkedProfilesProvider(account));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(nativeContactsControllerProvider).error ??
                'Could not unlink',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(contactLinkedProfilesProvider(account));
    final state = ref.watch(nativeContactsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.contact.displayName} · Profiles'),
        actions: [
          if (widget.contact.status == 'active')
            IconButton(
              tooltip: 'Create and link new Health Profile',
              onPressed: state.busy ? null : _createLinkedProfile,
              icon: const Icon(Icons.person_add_alt_1),
            ),
          IconButton(
            onPressed: () =>
                ref.invalidate(contactLinkedProfilesProvider(account)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: widget.contact.status == 'active'
          ? FloatingActionButton.extended(
              onPressed: state.busy ? null : () => _edit(),
              icon: const Icon(Icons.add_link),
              label: const Text('Link Profile'),
            )
          : null,
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load linked profiles: $error')),
        data: (items) => items.isEmpty
            ? const Center(
                child: Text('No Health Profiles linked to this Contact'),
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Relationship describes the patient relative to this Contact. Links do not themselves confer staff authority.',
                    ),
                  ),
                  for (final p in items)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.medical_information_outlined),
                        title: Text(p.fullName),
                        subtitle: Text(
                          '${p.profileId} · ${p.relationship?.name ?? 'unknown'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit relationship',
                              onPressed: state.busy
                                  ? null
                                  : () => _edit(existing: p),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Unlink',
                              onPressed:
                                  state.busy ||
                                      widget.contact.status != 'active'
                                  ? null
                                  : () => _unlink(p),
                              icon: const Icon(Icons.link_off),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _LinkProfileDialog extends StatefulWidget {
  const _LinkProfileDialog({required this.entityType, this.existing});
  final String entityType;
  final Profile? existing;
  @override
  State<_LinkProfileDialog> createState() => _LinkProfileDialogState();
}

class _LinkProfileDialogState extends State<_LinkProfileDialog> {
  late final TextEditingController _id = TextEditingController(
    text: widget.existing?.profileId ?? '',
  );
  late ProfileContactRelationship _relation =
      widget.existing?.relationship ?? ProfileContactRelationship.other;
  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = widget.entityType == 'organization'
        ? [
            ProfileContactRelationship.insurance,
            ProfileContactRelationship.other,
          ]
        : ProfileContactRelationship.values
              .where((r) => r != ProfileContactRelationship.insurance)
              .toList();
    if (!allowed.contains(_relation)) _relation = allowed.last;
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Link existing Health Profile'
            : 'Edit relationship',
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _id,
              enabled: widget.existing == null,
              decoration: const InputDecoration(
                labelText: 'Existing Profile ID',
                hintText: 'HP-YYMMNNNN',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProfileContactRelationship>(
              initialValue: _relation,
              decoration: const InputDecoration(
                labelText: 'Patient is this Contact’s',
              ),
              items: [
                for (final r in allowed)
                  DropdownMenuItem(value: r, child: Text(r.name)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _relation = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final id = _id.text.trim();
            if (id.isEmpty || id.contains('/')) return;
            Navigator.pop(context, (id: id, relationship: _relation));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
