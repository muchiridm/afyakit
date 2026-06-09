// lib/features/insurance/claim_packs/widgets/insurance_claim_detail_screen.dart

import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/providers/prescriptions_providers.dart';
import 'package:afyakit/features/clinical/prescriptions/services/prescriptions_service.dart';
import 'package:afyakit/features/insurance/claim_packs/controllers/insurance_claim_packs_controller.dart';
import 'package:afyakit/features/insurance/claim_packs/models/insurance_claim_pack.dart';
import 'package:afyakit/features/insurance/claim_packs/widgets/insurance_claim_form_dialog.dart';
import 'package:afyakit/features/insurance/documents/widgets/insurance_documents_panel.dart';
import 'package:afyakit/features/insurance/memberships/controllers/insurance_memberships_controller.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:afyakit/features/retail/invoices/widgets/invoice_detail_screen.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class InsuranceClaimDetailScreen extends ConsumerStatefulWidget {
  const InsuranceClaimDetailScreen({
    super.key,
    required this.claimPackId,
    this.patientId,
    this.initialClaimPack,
  });

  final String claimPackId;
  final String? patientId;
  final InsuranceClaimPack? initialClaimPack;

  @override
  ConsumerState<InsuranceClaimDetailScreen> createState() =>
      _InsuranceClaimDetailScreenState();
}

class _InsuranceClaimDetailScreenState
    extends ConsumerState<InsuranceClaimDetailScreen> {
  InsuranceClaimPack? _pack;
  bool _loading = false;
  String? _error;

  String get _patientId {
    return (_pack?.patientId ??
            widget.initialClaimPack?.patientId ??
            widget.patientId ??
            '')
        .trim();
  }

  @override
  void initState() {
    super.initState();

    _pack = widget.initialClaimPack;

    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final String claimPackId = widget.claimPackId.trim();
    final String patientId = _patientId;

    if (claimPackId.isEmpty) return;

    if (patientId.isEmpty) {
      setState(
        () => _error = 'Patient ID is required to load this claim pack.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final InsuranceClaimPack? pack = await ref
          .read(insuranceClaimPacksControllerProvider.notifier)
          .get(patientId: patientId, claimPackId: claimPackId);

      if (!mounted) return;

      setState(() {
        _pack = pack;
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

  Future<void> _editPack({String successMessage = 'Claim pack updated'}) async {
    final InsuranceClaimPack? pack = _pack;
    if (pack == null) return;

    final List<InsuranceMembership> memberships = ref
        .read(insuranceMembershipsControllerProvider)
        .items;

    final InsuranceClaimPackFormResult? result =
        await showDialog<InsuranceClaimPackFormResult>(
          context: context,
          builder: (_) => InsuranceClaimFormDialog(
            initial: pack,
            invoiceId: pack.invoiceId,
            invoiceNumber: pack.invoiceNumber,
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

    setState(() => _pack = updated);
    _snack(successMessage);
  }

  Future<void> _amendInvoice() {
    return _editPack(successMessage: 'Invoice updated');
  }

  Future<void> _amendPrescription() {
    return _editPack(successMessage: 'Prescription updated');
  }

  Future<void> _viewPrescription() async {
    final InsuranceClaimPack? pack = _pack;
    if (pack == null) return;

    final String patientId = pack.patientId.trim();
    final String prescriptionId = (pack.prescriptionId ?? '').trim();

    if (patientId.isEmpty) {
      _snack('Patient ID is missing.');
      return;
    }

    if (prescriptionId.isEmpty) {
      _snack('No prescription is linked to this claim pack.');
      return;
    }

    try {
      final PrescriptionsService svc = ref.read(prescriptionsServiceProvider);

      final Prescription prescription = await svc.get(
        patientId: patientId,
        prescriptionId: prescriptionId,
      );

      if (!mounted) return;

      final String url = await svc.downloadUrl(prescription.storagePath);

      if (!mounted) return;

      final Uri? uri = Uri.tryParse(url);

      if (uri == null) {
        _snack('Invalid prescription link.');
        return;
      }

      final bool ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!ok && mounted) {
        _snack('Could not open prescription.');
      }
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    }
  }

  void _openInvoice() {
    final InsuranceClaimPack? pack = _pack;
    if (pack == null) return;

    final String invoiceId = (pack.invoiceId ?? '').trim();

    if (invoiceId.isEmpty) {
      _snack('No invoice is linked to this claim pack.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final InsuranceClaimPack? pack = _pack;

    final bool busy =
        _loading || ref.watch(insuranceClaimPacksControllerProvider).isSaving;

    return AppPage(
      title: pack == null
          ? 'Claim Pack'
          : 'Claim Pack · ${pack.insurerClaimNo ?? pack.invoiceNumber ?? pack.claimPackId}',
      showBack: true,
      maxWidth: AppLayout.contentMaxWidth,
      padding: AppLayout.pagePadding,
      scrollable: false,
      actions: <Widget>[
        IconButton(
          tooltip: 'Refresh',
          onPressed: busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: pack == null || busy ? null : _editPack,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            if (_loading && pack == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorBanner(message: _error!)
            else if (pack == null)
              const _EmptyPack()
            else ...<Widget>[
              _ClaimPackSummaryCard(pack: pack),
              const SizedBox(height: 12),
              _InvoiceCard(
                pack: pack,
                busy: busy,
                onOpen: _openInvoice,
                onAmend: _amendInvoice,
              ),
              const SizedBox(height: 12),
              _PrescriptionCard(
                pack: pack,
                busy: busy,
                onView: _viewPrescription,
                onAmend: _amendPrescription,
              ),
              const SizedBox(height: 12),
              InsuranceDocumentsPanel(
                patientId: pack.patientId,
                claimPackId: pack.claimPackId,
                membershipId: pack.membershipId,
                payerContactId: pack.payerContactId,
                payerDisplayName: pack.payerDisplayName,
                title: 'Claim pack documents',
                emptyText: 'No supporting documents uploaded.',
              ),
              const SizedBox(height: 12),
              _ClaimPackDetailsCard(pack: pack),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClaimPackSummaryCard extends StatelessWidget {
  const _ClaimPackSummaryCard({required this.pack});

  final InsuranceClaimPack pack;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle(
              icon: Icons.assignment_outlined,
              title: 'Claim pack summary',
            ),
            const SizedBox(height: 12),
            _InfoRow('Patient', pack.patientDisplayName ?? pack.patientId),
            _InfoRow('Patient No.', pack.patientNo ?? pack.patientId),
            _InfoRow('Insurer', pack.payerDisplayName ?? pack.payerContactId),
            _InfoRow('Member No.', pack.memberNo),
            _InfoRow('Member Name', pack.memberName),
            _InfoRow('Principal', pack.principalName),
            _InfoRow('Scheme', pack.scheme),
            _InfoRow('Policy No.', pack.policyNo),
            _InfoRow('Medical Card No.', pack.medicalCardNo),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text('Status: ${pack.status.label}')),
                if (pack.hasInvoice) const Chip(label: Text('Invoice linked')),
                if (pack.hasPrescription)
                  const Chip(label: Text('Prescription linked')),
                if (!pack.isActive) const Chip(label: Text('Inactive')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.pack,
    required this.busy,
    required this.onOpen,
    required this.onAmend,
  });

  final InsuranceClaimPack pack;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onAmend;

  bool get _hasInvoice {
    return (pack.invoiceId ?? '').trim().isNotEmpty ||
        (pack.invoiceNumber ?? '').trim().isNotEmpty;
  }

  bool get _canOpen {
    return (pack.invoiceId ?? '').trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: _SectionTitle(
                    icon: Icons.receipt_long_outlined,
                    title: 'Invoice',
                  ),
                ),
                TextButton.icon(
                  onPressed: busy || !_canOpen ? null : onOpen,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: busy ? null : onAmend,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(_hasInvoice ? 'Amend' : 'Attach'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_hasInvoice)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.receipt_long_outlined),
                title: Text('No invoice linked'),
                subtitle: Text(
                  'Attach the patient invoice. The invoice is a key part of the insurance claim pack.',
                ),
              )
            else ...<Widget>[
              _InfoRow('Invoice Number', pack.invoiceNumber),
              _InfoRow('Invoice ID', pack.invoiceId),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({
    required this.pack,
    required this.busy,
    required this.onView,
    required this.onAmend,
  });

  final InsuranceClaimPack pack;
  final bool busy;
  final VoidCallback onView;
  final VoidCallback onAmend;

  bool get _hasPrescription {
    return (pack.prescriptionId ?? '').trim().isNotEmpty ||
        (pack.prescriptionNo ?? '').trim().isNotEmpty ||
        (pack.prescriberName ?? '').trim().isNotEmpty;
  }

  bool get _canView {
    return (pack.prescriptionId ?? '').trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: _SectionTitle(
                    icon: Icons.description_outlined,
                    title: 'Prescription',
                  ),
                ),
                TextButton.icon(
                  onPressed: busy || !_canView ? null : onView,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: busy ? null : onAmend,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(_hasPrescription ? 'Amend' : 'Attach'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_hasPrescription)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.description_outlined),
                title: Text('No prescription linked'),
                subtitle: Text(
                  'Attach or upload a prescription for this claim pack.',
                ),
              )
            else ...<Widget>[
              _InfoRow('Prescription ID', pack.prescriptionId),
              _InfoRow('Prescription no.', pack.prescriptionNo),
              _InfoRow('Prescriber', pack.prescriberName),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClaimPackDetailsCard extends StatelessWidget {
  const _ClaimPackDetailsCard({required this.pack});

  final InsuranceClaimPack pack;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            const _SectionTitle(
              icon: Icons.fact_check_outlined,
              title: 'Claim details',
            ),
            const SizedBox(height: 12),
            _InfoRow('Auth code', pack.authCode),
            _InfoRow('Insurer claim no.', pack.insurerClaimNo),
            _InfoRow('Visit no.', pack.visitNo),
            _InfoRow('Service date', pack.serviceDate),
            _InfoRow('Diagnosis', pack.diagnosis),
            _InfoRow('ICD-10', pack.icd10Code),
            _InfoRow('Notes', pack.notes),
            _InfoRow('Submitted at', pack.submittedAt),
            _InfoRow('Submitted by', pack.submittedByUid),
            _InfoRow('Created', pack.createdAt),
            _InfoRow('Updated', pack.updatedAt),
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
      children: <Widget>[
        Icon(icon),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final String display = (value ?? '').trim();

    if (display.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(display)),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Card.outlined(
      child: ListTile(
        leading: Icon(Icons.error_outline, color: scheme.error),
        title: const Text('Could not load claim pack'),
        subtitle: Text(message),
      ),
    );
  }
}

class _EmptyPack extends StatelessWidget {
  const _EmptyPack();

  @override
  Widget build(BuildContext context) {
    return const Card.outlined(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Claim pack not found.')),
      ),
    );
  }
}
