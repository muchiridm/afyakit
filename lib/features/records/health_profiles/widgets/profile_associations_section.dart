import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/profiles_service.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';
import 'profile_labels.dart';

class ProfileAssociationsSection extends ConsumerStatefulWidget {
  const ProfileAssociationsSection({
    super.key,
    required this.profile,
    required this.staffMode,
  });
  final Profile profile;
  final bool staffMode;
  @override
  ConsumerState<ProfileAssociationsSection> createState() =>
      ProfileAssociationsSectionState();
}

class ProfileAssociationsSectionState
    extends ConsumerState<ProfileAssociationsSection> {
  Future<List<RelatedProfile>>? _related;
  Future<List<ProfileLinkedContact>>? _payers;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant ProfileAssociationsSection old) {
    super.didUpdateWidget(old);
    if (old.profile.profileId != widget.profile.profileId ||
        old.staffMode != widget.staffMode ||
        old.profile.isActive != widget.profile.isActive) {
      _reload();
    }
  }

  void _reload() {
    if (!widget.profile.isActive) {
      _related = Future<List<RelatedProfile>>.value(const <RelatedProfile>[]);
      _payers = null;
      return;
    }
    final service = ref.read(profilesServiceProvider);
    _related = service.listRelatedProfiles(widget.profile.profileId);
    _payers = widget.staffMode
        ? service.listLinkedPayers(widget.profile.profileId)
        : null;
  }

  void _refresh() {
    setState(_reload);
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _addPayer() async {
    final accountCtl = TextEditingController();
    ProfileContactRelationship relationship = ProfileContactRelationship.other;
    try {
      final result = await showDialog<(String, ProfileContactRelationship)>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Link Native Contact'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: accountCtl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Native Contact account',
                    hintText: 'AC-XXXXXX',
                  ),
                ),
                DropdownButtonFormField<ProfileContactRelationship>(
                  initialValue: relationship,
                  decoration: const InputDecoration(labelText: 'Association'),
                  items: ProfileContactRelationship.values
                      .map(
                        (v) => DropdownMenuItem(value: v, child: Text(v.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) update(() => relationship = v);
                  },
                ),
                const Text(
                  'This describes the patient relative to the Contact; linking does not automatically authorise access or payment.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final account = accountCtl.text.trim().toUpperCase();
                  if (!RegExp(
                    r'^AC-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
                  ).hasMatch(account)) {
                    return;
                  }
                  Navigator.pop(context, (account, relationship));
                },
                child: const Text('Link'),
              ),
            ],
          ),
        ),
      );
      if (result == null) return;
      await ref
          .read(profilesServiceProvider)
          .linkContact(
            widget.profile.profileId,
            ProfileContactLinkInput(
              accountNumber: result.$1,
              relationship: result.$2,
            ),
          );
      if (mounted) _refresh();
    } catch (e) {
      _error(e);
    } finally {
      accountCtl.dispose();
    }
  }

  Future<void> _editContactLink(ProfileLinkedContact contact) async {
    var relationship = contact.relationship;
    final updated = await showDialog<ProfileContactRelationship>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Contact relationship'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact.contactDisplayName ?? contact.accountNumber),
              Text(contact.accountNumber),
              const SizedBox(height: 12),
              DropdownButtonFormField<ProfileContactRelationship>(
                initialValue: relationship,
                decoration: const InputDecoration(
                  labelText: 'Patient is this Contact’s…',
                ),
                items: ProfileContactRelationship.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(ProfilesLabels.relationship(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => relationship = value);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Changing a Self or family link changes the inferred Linked Profiles view.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, relationship),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (updated == null || updated == contact.relationship) return;
    try {
      await ref
          .read(profilesServiceProvider)
          .linkContact(
            widget.profile.profileId,
            ProfileContactLinkInput(
              accountNumber: contact.accountNumber,
              relationship: updated,
            ),
          );
      if (mounted) _refresh();
    } catch (error) {
      _error(error);
    }
  }

  static String _relatedLabel(ProfileRelationship relationship) {
    return switch (relationship) {
      ProfileRelationship.spouse => 'Spouse',
      ProfileRelationship.parent => 'Parent',
      ProfileRelationship.child => 'Child',
      ProfileRelationship.guardian => 'Guardian',
      ProfileRelationship.ward => 'Ward',
      ProfileRelationship.sibling => 'Sibling',
      ProfileRelationship.other => 'Other',
    };
  }

  Future<void> _removePayer(ProfileLinkedContact payer) async {
    try {
      await ref
          .read(profilesServiceProvider)
          .delinkContact(
            profileId: widget.profile.profileId,
            accountNumber: payer.accountNumber,
          );
      if (mounted) _refresh();
    } catch (e) {
      _error(e);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppCard(
        title: 'Linked Profiles',
        icon: Icons.people_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              title: Text(widget.profile.fullName),
              subtitle: Text(widget.profile.profileId),
              trailing: const Text('Current profile'),
            ),
            FutureBuilder<List<RelatedProfile>>(
              future: _related,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Linked profiles unavailable: ${snapshot.error}');
                }
                final list = snapshot.data ?? const <RelatedProfile>[];
                if (list.isEmpty) {
                  return const Text('No additional profiles linked.');
                }
                return Column(
                  children: list
                      .map(
                        (person) => ListTile(
                          dense: true,
                          title: Text(person.fullName),
                          subtitle: Text(person.profileId),
                          trailing: Text(_relatedLabel(person.relationship)),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            if (widget.staffMode)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Inferred from Native Contact relationships. To change a family relationship, edit the corresponding Contact link below.',
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppShape.gap14),
      if (widget.staffMode)
        AppCard(
          title: 'Linked Contacts / Payers',
          icon: Icons.account_balance_wallet_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<List<ProfileLinkedContact>>(
                future: _payers,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Linked payers unavailable: ${snapshot.error}');
                  }
                  final list = snapshot.data ?? const <ProfileLinkedContact>[];
                  if (list.isEmpty) {
                    return const Text('No Native Contacts linked.');
                  }
                  return Column(
                    children: list
                        .map(
                          (payer) => ListTile(
                            dense: true,
                            title: Text(
                              payer.contactDisplayName ?? payer.accountNumber,
                            ),
                            subtitle: Text(
                              '${payer.accountNumber} · ${ProfilesLabels.profilePerspectiveRelationship(payer.relationship)}',
                            ),
                            trailing: payer.isActive
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Edit relationship',
                                        onPressed: () =>
                                            _editContactLink(payer),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.link_off),
                                        tooltip: 'Unlink Contact',
                                        onPressed: () => _removePayer(payer),
                                      ),
                                    ],
                                  )
                                : const Text('Inactive'),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              TextButton.icon(
                onPressed: _addPayer,
                icon: const Icon(Icons.add_link),
                label: const Text('Link Native Contact'),
              ),
            ],
          ),
        ),
    ],
  );
}
