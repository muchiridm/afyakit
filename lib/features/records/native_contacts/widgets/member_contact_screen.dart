import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';

import '../native_contact.dart';
import '../native_contacts_service.dart';

/// Authenticated member's canonical Native Contact.
/// The account number is resolved by the backend.
final myNativeContactProvider = FutureProvider.autoDispose<NativeContact>((
  ref,
) async {
  final service = await ref.watch(nativeContactsServiceProvider.future);

  return service.getMine();
});

/// Health Profiles linked to the authenticated member's
/// canonical Native Contact.
///
/// Does not accept an account number from the frontend.
/// Does not use staff-only directory endpoints.
final myLinkedHealthProfilesProvider =
    FutureProvider.autoDispose<List<Profile>>((ref) async {
      final service = await ref.watch(nativeContactsServiceProvider.future);

      return service.listMyLinkedHealthProfiles();
    });

class MemberContactScreen extends ConsumerWidget {
  const MemberContactScreen({super.key, required this.user});

  final AuthUser? user;

  void _refresh(WidgetRef ref) {
    ref.invalidate(myNativeContactProvider);
    ref.invalidate(myLinkedHealthProfilesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(myNativeContactProvider);
    final profiles = ref.watch(myLinkedHealthProfilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Contact'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myNativeContactProvider);
          ref.invalidate(myLinkedHealthProfilesProvider);

          await Future.wait([
            ref.read(myNativeContactProvider.future).then<void>((_) {}),
            ref.read(myLinkedHealthProfilesProvider.future).then<void>((_) {}),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // --------------------------------------------
            // My Contact
            // --------------------------------------------
            contact.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Unable to load your Contact: $error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
              data: (c) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _Line('Account number', c.accountNumber),
                      _Line('Verified phone', c.verifiedPhone),
                      _Line('Verified app email', c.verifiedEmail),
                      _Line('Contact phone', c.phone),
                      _Line('Contact email', c.email),
                      _Line('Identification', c.idNumber),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --------------------------------------------
            // Linked Health Profiles
            // --------------------------------------------
            Text(
              'My Linked Health Profiles',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            profiles.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unable to load linked Health Profiles: $error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () =>
                            ref.invalidate(myLinkedHealthProfilesProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.folder_shared_outlined, size: 36),
                          SizedBox(height: 12),
                          Text(
                            'No Health Profiles linked to your account yet.',
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'An existing Health Profile must be linked '
                            'through the approved request process.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Card(
                  child: Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        if (index > 0) const Divider(height: 1),
                        _LinkedProfileTile(profile: items[index]),
                      ],
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // --------------------------------------------
            // Security information
            // --------------------------------------------
            const ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Verified identity is read-only'),
              subtitle: Text(
                'Contact changes do not grant access to Health '
                'Profiles. New links to existing Profiles '
                'require approval.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedProfileTile extends StatelessWidget {
  const _LinkedProfileTile({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final relationship = profile.relationship?.name ?? 'other';

    final label = switch (relationship) {
      'self' => 'Self',
      'child' => 'Child',
      'spouse' => 'Spouse',
      'parent' => 'Parent',
      'guardian' => 'Guardian',
      'insurance' => 'Insurance',
      _ => 'Other',
    };

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(profile.fullName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(profile.profileId),
          const SizedBox(height: 4),
          Text('Relationship: $label'),
        ],
      ),
      isThreeLine: true,
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(text == null || text.isEmpty ? 'Not available' : text),
        ],
      ),
    );
  }
}
