// lib/features/insurance/memberships/widgets/insurance_memberships_screen.dart
import 'package:afyakit/features/records/health_profiles/widgets/profiles_screen.dart';
import 'package:afyakit/features/insurance/memberships/controllers/insurance_memberships_controller.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:afyakit/features/insurance/memberships/widgets/insurance_membership_form_dialog.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/native_contacts_service.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InsuranceMembershipsScreen extends ConsumerStatefulWidget {
  const InsuranceMembershipsScreen({super.key});
  @override
  ConsumerState<InsuranceMembershipsScreen> createState() =>
      _InsuranceMembershipsScreenState();
}

class _InsuranceMembershipsScreenState
    extends ConsumerState<InsuranceMembershipsScreen> {
  final _searchCtl = TextEditingController();
  bool _activeOnly = true;
  bool _isLoadingPayers = false;
  String? _selectedPayerContactId;
  String? _payerError;
  List<NativeContact> _insurancePayers = const <NativeContact>[];
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_loadMemberships(), _loadInsurancePayers()]);
  }

  Future<void> _loadMemberships() {
    return ref
        .read(insuranceMembershipsControllerProvider.notifier)
        .load(
          search: _nullable(_searchCtl.text),
          payerContactId: _nullable(_selectedPayerContactId),
          isActive: _activeOnly ? true : null,
          perPage: 100,
          page: 1,
        );
  }

  Future<void> _loadInsurancePayers() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPayers = true;
      _payerError = null;
    });
    try {
      final svc = await ref.read(nativeContactsServiceProvider.future);
      final payers = <NativeContact>[];
      // The Native Contacts endpoint is paginated, without payer filtering.
      // Read successive app-scoped pages before filtering locally.
      for (var page = 1; ; page++) {
        final contacts = await svc.list(page: page, perPage: 100);
        payers.addAll(contacts.where((c) => c.isInsurancePayer));
        if (contacts.length < 100) break;
      }
      if (!mounted) return;
      setState(() {
        _insurancePayers = payers;
        _isLoadingPayers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPayers = false;
        _payerError = e.toString();
      });
    }
  }

  void _openHealthProfiles() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfilesScreen(allowExplicitContactLink: true),
      ),
    );
  }

  Future<void> _openEditDialog(InsuranceMembership membership) async {
    final input = await showDialog<InsuranceMembershipUpsertInput>(
      context: context,
      builder: (_) => InsuranceMembershipFormDialog(
        initial: membership,
        profileId: membership.profileId,
        profileDisplayName: membership.profileDisplayName,
        payerContactId: membership.payerContactId,
        payerDisplayName: membership.payerDisplayName,
      ),
    );
    if (input == null || !mounted) return;
    final updated = await ref
        .read(insuranceMembershipsControllerProvider.notifier)
        .update(membership.membershipId, input);
    if (!mounted) return;
    if (updated == null) {
      final error = ref.read(insuranceMembershipsControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to update membership')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Insurance membership updated')),
    );
    await _load();
  }

  Future<void> _deactivate(InsuranceMembership membership) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate membership?'),
        content: Text(
          'This will deactivate ${membership.displayTitle}. Existing claims remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(insuranceMembershipsControllerProvider.notifier)
        .delete(membership.membershipId);
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(insuranceMembershipsControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to deactivate membership')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Insurance membership deactivated')),
    );
    await _load();
  }

  void _clearFilters() {
    _searchCtl.clear();
    setState(() {
      _activeOnly = true;
      _selectedPayerContactId = null;
    });
    _load();
  }

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(insuranceMembershipsControllerProvider);
    final isBusy = state.isLoading || _isLoadingPayers;
    return AppPage(
      title: 'Insurance Members',
      showBack: true,
      maxWidth: AppLayout.contentMaxWidth,
      padding: AppLayout.pagePadding,
      scrollable: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: isBusy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: _openHealthProfiles,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Open Health Profiles'),
          ),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _MembershipFilters(
              searchCtl: _searchCtl,
              activeOnly: _activeOnly,
              isLoading: isBusy,
              selectedPayerContactId: _selectedPayerContactId,
              insurancePayers: _insurancePayers,
              onPayerChanged: (value) {
                setState(() => _selectedPayerContactId = value);
                _loadMemberships();
              },
              onActiveOnlyChanged: (value) {
                setState(() => _activeOnly = value);
                _loadMemberships();
              },
              onSearch: () {
                setState(() {});
                _loadMemberships();
              },
              onClear: _clearFilters,
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ErrorText(state.error!),
            ),
          if (_payerError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ErrorText(_payerError!),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: isBusy && state.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        _SectionHeader(
                          icon: Icons.verified_user_outlined,
                          title: 'Registered insurance members',
                          count: state.items.length,
                          subtitle:
                              'Full memberships with member number, scheme, policy and other claim details.',
                        ),
                        const SizedBox(height: 8),
                        if (state.items.isEmpty)
                          const _EmptyInlineState(
                            icon: Icons.verified_user_outlined,
                            title: 'No registered members',
                            message:
                                'Create a membership from a Health Profile with an insurance payer.',
                          )
                        else
                          ...state.items.map(
                            (membership) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _MembershipCard(
                                membership: membership,
                                onEdit: () => _openEditDialog(membership),
                                onDeactivate: () => _deactivate(membership),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipFilters extends StatelessWidget {
  const _MembershipFilters({
    required this.searchCtl,
    required this.activeOnly,
    required this.isLoading,
    required this.selectedPayerContactId,
    required this.insurancePayers,
    required this.onPayerChanged,
    required this.onActiveOnlyChanged,
    required this.onSearch,
    required this.onClear,
  });
  final TextEditingController searchCtl;
  final bool activeOnly;
  final bool isLoading;
  final String? selectedPayerContactId;
  final List<NativeContact> insurancePayers;
  final ValueChanged<String?> onPayerChanged;
  final ValueChanged<bool> onActiveOnlyChanged;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    final sortedPayers = insurancePayers.toList(growable: false)
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 360,
          child: TextField(
            controller: searchCtl,
            decoration: InputDecoration(
              labelText: 'Search insurance members',
              hintText: 'Patient, member no, scheme, policy...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: isLoading ? null : onSearch,
                icon: const Icon(Icons.arrow_forward),
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => onSearch(),
          ),
        ),
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<String?>(
            initialValue: selectedPayerContactId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Insurer',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All insurers'),
              ),
              ...sortedPayers.map(
                (payer) => DropdownMenuItem<String?>(
                  value: payer.id,
                  child: Text(
                    payer.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: isLoading ? null : onPayerChanged,
          ),
        ),
        FilterChip(
          selected: activeOnly,
          label: const Text('Active members only'),
          avatar: const Icon(Icons.check_circle_outline),
          onSelected: isLoading ? null : onActiveOnlyChanged,
        ),
        TextButton.icon(
          onPressed: isLoading ? null : onClear,
          icon: const Icon(Icons.clear),
          label: const Text('Clear'),
        ),
      ],
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.membership,
    required this.onEdit,
    required this.onDeactivate,
  });
  final InsuranceMembership membership;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      membership.payerLabel,
      if ((membership.scheme ?? '').trim().isNotEmpty)
        membership.scheme!.trim(),
      if ((membership.policyNo ?? '').trim().isNotEmpty)
        'Policy: ${membership.policyNo!.trim()}',
      if ((membership.medicalCardNo ?? '').trim().isNotEmpty)
        'Card: ${membership.medicalCardNo!.trim()}',
    ];
    final validity = [
      if ((membership.effectiveFrom ?? '').trim().isNotEmpty)
        'From ${membership.effectiveFrom}',
      if ((membership.effectiveTo ?? '').trim().isNotEmpty)
        'To ${membership.effectiveTo}',
    ].join(' · ');
    return Card.outlined(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(membership.isActive ? Icons.verified_user : Icons.block),
        ),
        title: Text(
          membership.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitleParts.isEmpty
                    ? 'No payer details'
                    : subtitleParts.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (validity.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(validity, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Deactivate',
              onPressed: membership.isActive ? onDeactivate : null,
              icon: const Icon(Icons.block),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final int count;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Chip(
                    label: Text('$count'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}

class _EmptyInlineState extends StatelessWidget {
  const _EmptyInlineState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
