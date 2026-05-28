// lib/features/insurance/claims/widgets/insurance_claim_detail_screen.dart

import 'package:afyakit/features/insurance/claims/controllers/insurance_claims_controller.dart';
import 'package:afyakit/features/insurance/claims/models/insurance_claim.dart';
import 'package:afyakit/features/insurance/claims/widgets/insurance_claim_form_dialog.dart';
import 'package:afyakit/features/insurance/memberships/controllers/insurance_memberships_controller.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class InsuranceClaimDetailScreen extends ConsumerStatefulWidget {
  const InsuranceClaimDetailScreen({
    super.key,
    required this.claimId,
    this.initialClaim,
  });

  final String claimId;
  final InsuranceClaim? initialClaim;

  @override
  ConsumerState<InsuranceClaimDetailScreen> createState() =>
      _InsuranceClaimDetailScreenState();
}

class _InsuranceClaimDetailScreenState
    extends ConsumerState<InsuranceClaimDetailScreen> {
  InsuranceClaim? _claim;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _claim = widget.initialClaim;

    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final claimId = widget.claimId.trim();
    if (claimId.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final claim = await ref
          .read(insuranceClaimsControllerProvider.notifier)
          .get(claimId);

      if (!mounted) return;

      setState(() {
        _claim = claim;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _editClaim() async {
    final claim = _claim;
    if (claim == null) return;

    final loadedMemberships = ref
        .read(insuranceMembershipsControllerProvider)
        .items;

    final input = await showDialog<InsuranceClaimUpsertInput>(
      context: context,
      builder: (_) => InsuranceClaimFormDialog(
        initial: claim,
        invoiceId: claim.invoiceId,
        invoiceNumber: claim.invoiceNumber,
        memberships: loadedMemberships,
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

    setState(() => _claim = updated);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Insurance claim updated')));
  }

  Future<void> _detachClaimForm(InsuranceClaim claim) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detach claim form?'),
        content: const Text(
          'This removes the claim form link from this claim. It does not delete the file from storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Detach'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final updated = await ref
        .read(insuranceClaimsControllerProvider.notifier)
        .detachClaimForm(claim.claimId);

    if (!mounted) return;

    if (updated == null) {
      final error = ref.read(insuranceClaimsControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to detach claim form')),
      );
      return;
    }

    setState(() => _claim = updated);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Claim form detached')));
  }

  Future<void> _detachPrescription(InsuranceClaim claim) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detach prescription?'),
        content: const Text(
          'This removes the prescription reference from this claim. The patient prescription record remains unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Detach'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final updated = await ref
        .read(insuranceClaimsControllerProvider.notifier)
        .detachPrescription(claim.claimId);

    if (!mounted) return;

    if (updated == null) {
      final error = ref.read(insuranceClaimsControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to detach prescription')),
      );
      return;
    }

    setState(() => _claim = updated);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Prescription detached')));
  }

  Future<void> _openUrl(String? value) async {
    final raw = (value ?? '').trim();

    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document link available')),
      );
      return;
    }

    final uri = Uri.tryParse(raw);

    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid document link')));
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open document')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final claim = _claim;
    final busy =
        _loading || ref.watch(insuranceClaimsControllerProvider).isSaving;

    return AppPage(
      title: claim == null
          ? 'Insurance Claim'
          : 'Claim · ${claim.invoiceNumber ?? claim.invoiceId}',
      showBack: true,
      maxWidth: AppLayout.contentMaxWidth,
      padding: AppLayout.pagePadding,
      scrollable: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: claim == null || busy ? null : _editClaim,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit claim'),
          ),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_loading && claim == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorBanner(message: _error!)
            else if (claim == null)
              const _EmptyClaim()
            else ...[
              _ClaimSummaryCard(claim: claim),
              const SizedBox(height: 12),
              _ClaimDocumentsCard(
                claim: claim,
                onOpenClaimForm: () => _openUrl(claim.claimFormUrl),
                onOpenPrescription: () => _openUrl(claim.prescriptionUrl),
                onOpenInvoicePdf: () => _openUrl(claim.invoicePdfUrl),
                onOpenEtims: () => _openUrl(claim.etimsUrl),
                onDetachClaimForm: () => _detachClaimForm(claim),
                onDetachPrescription: () => _detachPrescription(claim),
              ),
              const SizedBox(height: 12),
              _ClaimDetailsCard(claim: claim),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClaimSummaryCard extends StatelessWidget {
  const _ClaimSummaryCard({required this.claim});

  final InsuranceClaim claim;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.assignment_outlined,
              title: 'Claim summary',
            ),
            const SizedBox(height: 12),
            _InfoRow('Patient', claim.patientDisplayName ?? claim.patientId),
            _InfoRow('Patient No.', claim.patientNo ?? claim.patientId),
            _InfoRow('Insurer', claim.payerDisplayName ?? claim.payerContactId),
            _InfoRow('Member No.', claim.memberNo),
            _InfoRow('Member Name', claim.memberName),
            _InfoRow('Principal', claim.principalName),
            _InfoRow('Scheme', claim.scheme),
            _InfoRow('Policy No.', claim.policyNo),
            _InfoRow('Medical Card No.', claim.medicalCardNo),
            _InfoRow('Invoice', claim.invoiceNumber ?? claim.invoiceId),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Claim: ${claim.status.label}')),
                if (claim.claimFormStatus != null)
                  Chip(label: Text('Form: ${claim.claimFormStatus!.label}')),
                if (claim.hasPrescriptionEvidence)
                  const Chip(label: Text('Prescription: Attached')),
                if (claim.etimsStatus != null)
                  Chip(label: Text('eTIMS: ${claim.etimsStatus!.label}')),
                if (!claim.isActive) const Chip(label: Text('Inactive')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimDocumentsCard extends StatelessWidget {
  const _ClaimDocumentsCard({
    required this.claim,
    required this.onOpenClaimForm,
    required this.onOpenPrescription,
    required this.onOpenInvoicePdf,
    required this.onOpenEtims,
    required this.onDetachClaimForm,
    required this.onDetachPrescription,
  });

  final InsuranceClaim claim;
  final VoidCallback onOpenClaimForm;
  final VoidCallback onOpenPrescription;
  final VoidCallback onOpenInvoicePdf;
  final VoidCallback onOpenEtims;
  final VoidCallback onDetachClaimForm;
  final VoidCallback onDetachPrescription;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _SectionTitle(
              icon: Icons.folder_outlined,
              title: 'Claim pack',
            ),
            const SizedBox(height: 12),
            _DocumentTile(
              title: 'Claim form',
              subtitle: _claimFormSubtitle(claim),
              icon: Icons.assignment_outlined,
              hasLink: _hasText(claim.claimFormUrl),
              onOpen: onOpenClaimForm,
              secondaryAction: claim.hasClaimForm
                  ? TextButton.icon(
                      onPressed: onDetachClaimForm,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Detach'),
                    )
                  : null,
            ),
            const Divider(height: 1),
            _DocumentTile(
              title: 'Prescription',
              subtitle: _prescriptionSubtitle(claim),
              icon: Icons.medication_outlined,
              hasLink: _hasText(claim.prescriptionUrl),
              onOpen: onOpenPrescription,
              secondaryAction: claim.hasPrescriptionEvidence
                  ? TextButton.icon(
                      onPressed: onDetachPrescription,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Detach'),
                    )
                  : null,
            ),
            const Divider(height: 1),
            _DocumentTile(
              title: 'Invoice PDF',
              subtitle: claim.invoiceNumber ?? claim.invoiceId,
              icon: Icons.receipt_long_outlined,
              hasLink: _hasText(claim.invoicePdfUrl),
              onOpen: onOpenInvoicePdf,
            ),
            const Divider(height: 1),
            _DocumentTile(
              title: 'eTIMS',
              subtitle: _etimsSubtitle(claim),
              icon: Icons.verified_outlined,
              hasLink: _hasText(claim.etimsUrl),
              onOpen: onOpenEtims,
            ),
            const SizedBox(height: 12),
            _ReadinessBanner(claim: claim),
          ],
        ),
      ),
    );
  }

  static String _claimFormSubtitle(InsuranceClaim claim) {
    final parts = <String>[
      claim.claimFormStatus?.label ?? 'Pending',
      if (_hasText(claim.claimFormFileName)) claim.claimFormFileName!.trim(),
      if (_hasText(claim.claimFormContentType))
        claim.claimFormContentType!.trim(),
      if (claim.claimFormSizeBytes != null)
        _formatBytes(claim.claimFormSizeBytes!),
    ];

    return parts.join(' · ');
  }

  static String _prescriptionSubtitle(InsuranceClaim claim) {
    final parts = <String>[
      if (_hasText(claim.prescriptionFileName))
        claim.prescriptionFileName!.trim(),
      if (_hasText(claim.prescriptionNo)) 'Rx No: ${claim.prescriptionNo}',
      if (_hasText(claim.prescriptionId)) 'ID: ${claim.prescriptionId}',
    ];

    return parts.isEmpty ? 'Not attached' : parts.join(' · ');
  }

  static String _etimsSubtitle(InsuranceClaim claim) {
    final parts = <String>[
      if (claim.etimsStatus != null) claim.etimsStatus!.label,
      if (_hasText(claim.etimsNo)) 'No: ${claim.etimsNo}',
    ];

    return parts.isEmpty ? 'Not available' : parts.join(' · ');
  }

  static bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';

    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';

    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class _ClaimDetailsCard extends StatelessWidget {
  const _ClaimDetailsCard({required this.claim});

  final InsuranceClaim claim;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _SectionTitle(
              icon: Icons.fact_check_outlined,
              title: 'Claim details',
            ),
            const SizedBox(height: 12),
            _InfoRow('Auth code', claim.authCode),
            _InfoRow('Claim no.', claim.claimNo),
            _InfoRow('Visit no.', claim.visitNo),
            _InfoRow('Service date', claim.serviceDate),
            _InfoRow('Prescription no.', claim.prescriptionNo),
            _InfoRow('Prescriber', claim.prescriberName),
            _InfoRow('Diagnosis', claim.diagnosis),
            _InfoRow('ICD-10', claim.icd10Code),
            _InfoRow('Investigations', claim.investigations),
            _InfoRow(
              'Treatment recommendations',
              claim.treatmentRecommendations,
            ),
            _InfoRow('Notes', claim.notes),
            _InfoRow('Submitted at', claim.submittedAt),
            _InfoRow('Submitted by', claim.submittedByUid),
            _InfoRow('Created', claim.createdAt),
            _InfoRow('Updated', claim.updatedAt),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.hasLink,
    required this.onOpen,
    this.secondaryAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool hasLink;
  final VoidCallback onOpen;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final cleanSubtitle = subtitle.trim();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(
        cleanSubtitle.isEmpty ? 'Not available' : cleanSubtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (secondaryAction != null) secondaryAction!,
          TextButton.icon(
            onPressed: hasLink ? onOpen : null,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class _ReadinessBanner extends StatelessWidget {
  const _ReadinessBanner({required this.claim});

  final InsuranceClaim claim;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final missing = <String>[
      if (!claim.hasClaimForm) 'claim form',
      if (!claim.hasPrescriptionEvidence) 'prescription',
      if (!claim.hasEtimsEvidence) 'eTIMS',
    ];

    final ready = missing.isEmpty && claim.isReadyForSubmission;

    return Material(
      color: ready ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              ready ? Icons.check_circle_outline : Icons.info_outline,
              color: ready
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ready
                    ? 'Claim pack is ready for submission.'
                    : 'Missing: ${missing.join(', ')}.',
                style: TextStyle(
                  color: ready
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final clean = (value ?? '').trim();
    if (clean.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: SelectableText(clean)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

class _EmptyClaim extends StatelessWidget {
  const _EmptyClaim();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(48),
      child: Center(child: Text('Claim not found.')),
    );
  }
}
