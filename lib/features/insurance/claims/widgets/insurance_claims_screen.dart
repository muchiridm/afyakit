// lib/features/insurance/claims/widgets/insurance_claims_screen.dart

import 'package:afyakit/features/insurance/claims/controllers/insurance_claims_controller.dart';
import 'package:afyakit/features/insurance/claims/models/insurance_claim.dart';
import 'package:afyakit/features/insurance/claims/widgets/insurance_claim_detail_screen.dart';
import 'package:afyakit/features/insurance/claims/widgets/insurance_claim_form_dialog.dart';
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
  final _searchCtl = TextEditingController();

  bool _activeOnly = true;

  @override
  void initState() {
    super.initState();

    Future<void>.microtask(() async {
      await Future.wait([_loadClaims(), _loadMemberships()]);
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadClaims() {
    return ref
        .read(insuranceClaimsControllerProvider.notifier)
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
    await Future.wait([_loadClaims(), _loadMemberships()]);
  }

  Future<void> _openCreateInvoicePrompt() async {
    final invoiceContext = await showDialog<_ClaimInvoiceContext>(
      context: context,
      builder: (_) => const _ClaimInvoiceContextDialog(),
    );

    if (invoiceContext == null || !mounted) return;

    final memberships = ref.read(insuranceMembershipsControllerProvider).items;

    final input = await showDialog<InsuranceClaimUpsertInput>(
      context: context,
      builder: (_) => InsuranceClaimFormDialog(
        invoiceId: invoiceContext.invoiceId,
        invoiceNumber: invoiceContext.invoiceNumber,
        memberships: memberships,
      ),
    );

    if (input == null || !mounted) return;

    final claim = await ref
        .read(insuranceClaimsControllerProvider.notifier)
        .create(input);

    if (!mounted) return;

    if (claim == null) {
      final error = ref.read(insuranceClaimsControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to create insurance claim')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Insurance claim saved and invoice updated'),
      ),
    );

    await _loadClaims();
  }

  Future<void> _openEditDialog(InsuranceClaim claim) async {
    final loadedMemberships = ref
        .read(insuranceMembershipsControllerProvider)
        .items;

    final memberships = _withClaimMembershipFallback(
      claim: claim,
      memberships: loadedMemberships,
    );

    final input = await showDialog<InsuranceClaimUpsertInput>(
      context: context,
      builder: (_) => InsuranceClaimFormDialog(
        initial: claim,
        invoiceId: claim.invoiceId,
        invoiceNumber: claim.invoiceNumber,
        memberships: memberships,
        initialMembershipId: claim.membershipId,
      ),
    );

    if (input == null || !mounted) return;

    final updated = await ref
        .read(insuranceClaimsControllerProvider.notifier)
        .update(claim.claimId, input);

    if (!mounted) return;

    if (updated == null) {
      final error = ref.read(insuranceClaimsControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to update insurance claim')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Insurance claim updated and invoice synced'),
      ),
    );

    await _loadClaims();
  }

  Future<void> _deactivate(InsuranceClaim claim) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel claim?'),
        content: Text(
          'This will mark claim ${claim.claimId} as cancelled/inactive. The record will remain for audit history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel claim'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await ref
        .read(insuranceClaimsControllerProvider.notifier)
        .delete(claim.claimId);

    if (!mounted) return;

    if (!ok) {
      final error = ref.read(insuranceClaimsControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to cancel claim')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Insurance claim cancelled')));

    await _loadClaims();
  }

  List<InsuranceMembership> _withClaimMembershipFallback({
    required InsuranceClaim claim,
    required List<InsuranceMembership> memberships,
  }) {
    final exists = memberships.any((m) => m.membershipId == claim.membershipId);
    if (exists) return memberships;

    final fallback = InsuranceMembership(
      membershipId: claim.membershipId,
      patientId: claim.patientId,
      patientNo: claim.patientNo,
      patientDisplayName: claim.patientDisplayName,
      payerContactId: claim.payerContactId,
      payerDisplayName: claim.payerDisplayName,
      memberNo: claim.memberNo,
      memberName: claim.memberName,
      principalName: claim.principalName,
      scheme: claim.scheme,
      medicalCardNo: claim.medicalCardNo,
      policyNo: claim.policyNo,
      isActive: claim.isActive,
    );

    return [fallback, ...memberships];
  }

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final claimsState = ref.watch(insuranceClaimsControllerProvider);
    final membershipsState = ref.watch(insuranceMembershipsControllerProvider);

    final isBusy = claimsState.isLoading || membershipsState.isLoading;

    return AppPage(
      title: 'Insurance Claims',
      showBack: true,
      maxWidth: AppLayout.contentMaxWidth,
      padding: AppLayout.pagePadding,
      scrollable: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: isBusy ? null : _refreshAll,
          icon: const Icon(Icons.refresh),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: claimsState.isSaving || membershipsState.items.isEmpty
                ? null
                : _openCreateInvoicePrompt,
            icon: const Icon(Icons.add),
            label: const Text('Add Claim'),
          ),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _ClaimFilters(
              searchCtl: _searchCtl,
              activeOnly: _activeOnly,
              isLoading: claimsState.isLoading,
              onActiveOnlyChanged: (value) {
                setState(() => _activeOnly = value);
                _loadClaims();
              },
              onSearch: _loadClaims,
            ),
          ),
          if (membershipsState.items.isEmpty && !membershipsState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _InfoBanner(
                message:
                    'No active insurance memberships found. Create a membership before adding claims.',
              ),
            ),
          if (claimsState.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ErrorText(claimsState.error!),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              child: claimsState.isLoading && claimsState.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : claimsState.items.isEmpty
                  ? const _EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No insurance claims',
                      message:
                          'Create a claim from an invoice and verified insurance membership.',
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: claimsState.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final claim = claimsState.items[index];

                        return _ClaimCard(
                          claim: claim,
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => InsuranceClaimDetailScreen(
                                claimId: claim.claimId,
                                initialClaim: claim,
                              ),
                            ),
                          ),
                          onEdit: () => _openEditDialog(claim),
                          onCancel: () => _deactivate(claim),
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

class _ClaimFilters extends StatelessWidget {
  const _ClaimFilters({
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
      children: [
        SizedBox(
          width: 380,
          child: TextField(
            controller: searchCtl,
            decoration: InputDecoration(
              labelText: 'Search claims',
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

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({
    required this.claim,
    required this.onOpen,
    required this.onEdit,
    required this.onCancel,
  });

  final InsuranceClaim claim;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final titleParts = <String>[
      if ((claim.patientDisplayName ?? '').trim().isNotEmpty)
        claim.patientDisplayName!.trim()
      else
        claim.patientId,
      claim.invoiceNumber?.trim().isNotEmpty == true
          ? claim.invoiceNumber!.trim()
          : claim.invoiceId,
    ];

    final subtitleParts = <String>[
      if ((claim.payerDisplayName ?? '').trim().isNotEmpty)
        claim.payerDisplayName!.trim(),
      'Member: ${claim.memberNo}',
      if ((claim.scheme ?? '').trim().isNotEmpty) claim.scheme!.trim(),
      if ((claim.authCode ?? '').trim().isNotEmpty)
        'Auth: ${claim.authCode!.trim()}',
      if ((claim.claimNo ?? '').trim().isNotEmpty)
        'Claim: ${claim.claimNo!.trim()}',
      if ((claim.etimsNo ?? '').trim().isNotEmpty)
        'eTIMS: ${claim.etimsNo!.trim()}',
    ];

    return Card.outlined(
      child: ListTile(
        onTap: onOpen,
        mouseCursor: SystemMouseCursors.click,
        leading: CircleAvatar(
          child: Icon(claim.isActive ? Icons.assignment : Icons.block),
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
          children: [
            _ClaimStatusChip(status: claim.status),
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Cancel claim',
              onPressed: claim.isActive ? onCancel : null,
              icon: const Icon(Icons.block),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ClaimStatusChip extends StatelessWidget {
  const _ClaimStatusChip({required this.status});

  final InsuranceClaimStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ClaimInvoiceContext {
  const _ClaimInvoiceContext({required this.invoiceId, this.invoiceNumber});

  final String invoiceId;
  final String? invoiceNumber;
}

class _ClaimInvoiceContextDialog extends StatefulWidget {
  const _ClaimInvoiceContextDialog();

  @override
  State<_ClaimInvoiceContextDialog> createState() =>
      _ClaimInvoiceContextDialogState();
}

class _ClaimInvoiceContextDialogState
    extends State<_ClaimInvoiceContextDialog> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceIdCtl = TextEditingController();
  final _invoiceNumberCtl = TextEditingController();

  @override
  void dispose() {
    _invoiceIdCtl.dispose();
    _invoiceNumberCtl.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Invoice ID is required';
    return null;
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final invoiceNumber = _invoiceNumberCtl.text.trim();

    Navigator.of(context).pop(
      _ClaimInvoiceContext(
        invoiceId: _invoiceIdCtl.text.trim(),
        invoiceNumber: invoiceNumber.isEmpty ? null : invoiceNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Link invoice to insurance claim'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _invoiceIdCtl,
                decoration: const InputDecoration(
                  labelText: 'Zoho Invoice ID',
                  hintText: 'Example: 7052134000001194001',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _invoiceNumberCtl,
                decoration: const InputDecoration(
                  labelText: 'Invoice Number',
                  hintText: 'Optional display helper',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Continue')),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
