// lib/features/insurance/claim_packs/widgets/insurance_claims_screen.dart

import 'package:afyakit/features/insurance/claim_packs/controllers/insurance_claim_packs_controller.dart';
import 'package:afyakit/features/insurance/claim_packs/models/insurance_claim_pack.dart';
import 'package:afyakit/features/insurance/claim_packs/widgets/insurance_claim_detail_screen.dart';
import 'package:afyakit/features/insurance/claim_packs/widgets/insurance_claim_form_dialog.dart';
import 'package:afyakit/features/insurance/memberships/controllers/insurance_memberships_controller.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InsuranceClaimsScreen extends ConsumerStatefulWidget {
  const InsuranceClaimsScreen({super.key});

  @override
  ConsumerState<InsuranceClaimsScreen> createState() =>
      _InsuranceClaimsScreenState();
}

class _InsuranceClaimsScreenState extends ConsumerState<InsuranceClaimsScreen> {
  final TextEditingController _searchCtl = TextEditingController();

  bool _activeOnly = true;

  @override
  void initState() {
    super.initState();

    Future<void>.microtask(_refreshAll);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadPacks() {
    return ref
        .read(insuranceClaimPacksControllerProvider.notifier)
        .load(
          search: _nullable(_searchCtl.text),
          isActive: _activeOnly ? true : null,
          perPage: 100,
          page: 1,
        );
  }

  Future<void> _loadMemberships() {
    return ref
        .read(insuranceMembershipsControllerProvider.notifier)
        .load(isActive: true, perPage: 200, page: 1);
  }

  Future<void> _refreshAll() async {
    await Future.wait(<Future<void>>[_loadPacks(), _loadMemberships()]);
  }

  Future<void> _openCreateDialog() async {
    final List<InsuranceMembership> memberships = ref
        .read(insuranceMembershipsControllerProvider)
        .items;

    if (memberships.isEmpty) {
      _snack('Create an active insurance membership first.');
      return;
    }

    final InsuranceClaimPackFormResult? result =
        await showDialog<InsuranceClaimPackFormResult>(
          context: context,
          builder: (_) => InsuranceClaimFormDialog(memberships: memberships),
        );

    if (result == null || !mounted) return;

    final InsuranceClaimPack? pack = await ref
        .read(insuranceClaimPacksControllerProvider.notifier)
        .create(patientId: result.patientId, input: result.createInput);

    if (!mounted) return;

    if (pack == null) {
      final String? error = ref
          .read(insuranceClaimPacksControllerProvider)
          .error;
      _snack(error ?? 'Failed to create claim pack');
      return;
    }

    _snack('Claim pack created');

    await _loadPacks();

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InsuranceClaimDetailScreen(
          claimPackId: pack.claimPackId,
          patientId: pack.patientId,
          initialClaimPack: pack,
        ),
      ),
    );
  }

  Future<void> _openEditDialog(InsuranceClaimPack pack) async {
    final List<InsuranceMembership> loadedMemberships = ref
        .read(insuranceMembershipsControllerProvider)
        .items;

    final List<InsuranceMembership> memberships = _withPackMembershipFallback(
      pack: pack,
      memberships: loadedMemberships,
    );

    final InsuranceClaimPackFormResult? result =
        await showDialog<InsuranceClaimPackFormResult>(
          context: context,
          builder: (_) => InsuranceClaimFormDialog(
            initial: pack,
            memberships: memberships,
            initialMembershipId: pack.membershipId,
          ),
        );

    if (result == null || !mounted) return;

    final InsuranceClaimPack? updated = await ref
        .read(insuranceClaimPacksControllerProvider.notifier)
        .update(
          patientId: pack.patientId,
          claimPackId: pack.claimPackId,
          input: result.updateInput,
        );

    if (!mounted) return;

    if (updated == null) {
      final String? error = ref
          .read(insuranceClaimPacksControllerProvider)
          .error;
      _snack(error ?? 'Failed to update claim pack');
      return;
    }

    _snack('Claim pack updated');

    await _loadPacks();
  }

  Future<void> _cancelPack(InsuranceClaimPack pack) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel claim pack?'),
        content: Text(
          'This will mark ${pack.claimPackId} as cancelled and inactive. The record remains for audit history.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel pack'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final bool ok = await ref
        .read(insuranceClaimPacksControllerProvider.notifier)
        .delete(patientId: pack.patientId, claimPackId: pack.claimPackId);

    if (!mounted) return;

    if (!ok) {
      final String? error = ref
          .read(insuranceClaimPacksControllerProvider)
          .error;
      _snack(error ?? 'Failed to cancel claim pack');
      return;
    }

    _snack('Claim pack cancelled');

    await _loadPacks();
  }

  List<InsuranceMembership> _withPackMembershipFallback({
    required InsuranceClaimPack pack,
    required List<InsuranceMembership> memberships,
  }) {
    final bool exists = memberships.any(
      (InsuranceMembership m) => m.membershipId == pack.membershipId,
    );
    if (exists) return memberships;

    final InsuranceMembership fallback = InsuranceMembership(
      membershipId: pack.membershipId,
      patientId: pack.patientId,
      patientNo: pack.patientNo,
      patientDisplayName: pack.patientDisplayName,
      payerContactId: pack.payerContactId ?? '',
      payerDisplayName: pack.payerDisplayName,
      memberNo: pack.memberNo ?? '',
      memberName: pack.memberName,
      principalName: pack.principalName,
      scheme: pack.scheme,
      medicalCardNo: pack.medicalCardNo,
      policyNo: pack.policyNo,
      isActive: pack.isActive,
    );

    return <InsuranceMembership>[fallback, ...memberships];
  }

  void _openPack(InsuranceClaimPack pack) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InsuranceClaimDetailScreen(
          claimPackId: pack.claimPackId,
          patientId: pack.patientId,
          initialClaimPack: pack,
        ),
      ),
    );
  }

  String? _nullable(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final InsuranceClaimPacksState packsState = ref.watch(
      insuranceClaimPacksControllerProvider,
    );
    final membershipsState = ref.watch(insuranceMembershipsControllerProvider);

    final bool isBusy = packsState.isLoading || membershipsState.isLoading;

    return AppPage(
      title: 'Insurance Claim Packs',
      showBack: true,
      maxWidth: AppLayout.contentMaxWidth,
      padding: AppLayout.pagePadding,
      scrollable: false,
      actions: <Widget>[
        IconButton(
          tooltip: 'Refresh',
          onPressed: isBusy ? null : _refreshAll,
          icon: const Icon(Icons.refresh),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: packsState.isSaving || membershipsState.items.isEmpty
                ? null
                : _openCreateDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Pack'),
          ),
        ),
      ],
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _ClaimPackFilters(
              searchCtl: _searchCtl,
              activeOnly: _activeOnly,
              isLoading: packsState.isLoading,
              onActiveOnlyChanged: (bool value) {
                setState(() => _activeOnly = value);
                _loadPacks();
              },
              onSearch: _loadPacks,
            ),
          ),
          if (membershipsState.items.isEmpty && !membershipsState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _InfoBanner(
                message:
                    'No active insurance memberships found. Create a membership before adding claim packs.',
              ),
            ),
          if (packsState.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ErrorText(packsState.error!),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              child: packsState.isLoading && packsState.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : packsState.items.isEmpty
                  ? const _EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No claim packs',
                      message:
                          'Create a claim pack, then upload claim forms and supporting documents from the detail screen.',
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: packsState.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final InsuranceClaimPack pack = packsState.items[index];

                        return _ClaimPackCard(
                          pack: pack,
                          onOpen: () => _openPack(pack),
                          onEdit: () => _openEditDialog(pack),
                          onCancel: () => _cancelPack(pack),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimPackFilters extends StatelessWidget {
  const _ClaimPackFilters({
    required this.searchCtl,
    required this.activeOnly,
    required this.isLoading,
    required this.onActiveOnlyChanged,
    required this.onSearch,
  });

  final TextEditingController searchCtl;
  final bool activeOnly;
  final bool isLoading;
  final ValueChanged<bool> onActiveOnlyChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 420,
          child: TextField(
            controller: searchCtl,
            decoration: InputDecoration(
              labelText: 'Search claim packs',
              hintText: 'Patient, invoice, member no, claim no, auth...',
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
        FilterChip(
          selected: activeOnly,
          label: const Text('Active only'),
          avatar: const Icon(Icons.check_circle_outline),
          onSelected: isLoading ? null : onActiveOnlyChanged,
        ),
      ],
    );
  }
}

class _ClaimPackCard extends StatelessWidget {
  const _ClaimPackCard({
    required this.pack,
    required this.onOpen,
    required this.onEdit,
    required this.onCancel,
  });

  final InsuranceClaimPack pack;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final List<String> titleParts = <String>[
      if ((pack.patientDisplayName ?? '').trim().isNotEmpty)
        pack.patientDisplayName!.trim()
      else
        pack.patientId,
      if ((pack.invoiceNumber ?? '').trim().isNotEmpty)
        pack.invoiceNumber!.trim()
      else if ((pack.invoiceId ?? '').trim().isNotEmpty)
        pack.invoiceId!.trim()
      else
        pack.claimPackId,
    ];

    final List<String> subtitleParts = <String>[
      pack.status.label,
      if ((pack.payerDisplayName ?? '').trim().isNotEmpty)
        pack.payerDisplayName!.trim(),
      if ((pack.memberNo ?? '').trim().isNotEmpty)
        'Member: ${pack.memberNo!.trim()}',
      if ((pack.scheme ?? '').trim().isNotEmpty) pack.scheme!.trim(),
      if ((pack.authCode ?? '').trim().isNotEmpty)
        'Auth: ${pack.authCode!.trim()}',
      if ((pack.insurerClaimNo ?? '').trim().isNotEmpty)
        'Claim: ${pack.insurerClaimNo!.trim()}',
      if (pack.hasPrescription) 'Rx linked',
      if (pack.hasInvoice) 'Invoice linked',
    ];

    return Card.outlined(
      child: ListTile(
        onTap: onOpen,
        mouseCursor: SystemMouseCursors.click,
        leading: CircleAvatar(
          child: Icon(pack.isActive ? Icons.assignment : Icons.block),
        ),
        title: Text(
          titleParts.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitleParts.join(' · '),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Chip(label: Text(pack.status.label)),
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Cancel',
              onPressed: pack.isActive ? onCancel : null,
              icon: const Icon(Icons.cancel_outlined),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(message),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Text(message, style: TextStyle(color: scheme.error));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        const SizedBox(height: 96),
        Icon(icon, size: 48),
        const SizedBox(height: 12),
        Center(child: Text(title, style: theme.textTheme.titleMedium)),
        const SizedBox(height: 8),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
