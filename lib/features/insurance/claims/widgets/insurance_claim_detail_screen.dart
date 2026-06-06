// lib/features/insurance/claims/widgets/insurance_claim_detail_screen.dart

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/clinical/prescriptions/controllers/prescriptions_controller.dart';
import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/providers/prescriptions_providers.dart';
import 'package:afyakit/features/clinical/prescriptions/services/prescriptions_service.dart';
import 'package:afyakit/features/clinical/prescriptions/widgets/prescription_picker.dart';
import 'package:afyakit/features/insurance/claims/controllers/insurance_claims_controller.dart';
import 'package:afyakit/features/insurance/claims/models/insurance_claim.dart';
import 'package:afyakit/features/insurance/claims/services/insurance_claims_service.dart';
import 'package:afyakit/features/insurance/claims/widgets/insurance_claim_form_dialog.dart';
import 'package:afyakit/features/insurance/memberships/controllers/insurance_memberships_controller.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:afyakit/features/retail/invoices/controllers/invoice_action_controller.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class InsuranceClaimDetailScreen extends ConsumerStatefulWidget {
  const InsuranceClaimDetailScreen({
    super.key,
    required this.claimId,
    this.patientId,
    this.initialClaim,
  });

  final String claimId;
  final String? patientId;
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

  String get _patientId {
    return (_claim?.patientId ??
            widget.initialClaim?.patientId ??
            widget.patientId ??
            '')
        .trim();
  }

  @override
  void initState() {
    super.initState();

    _claim = widget.initialClaim;

    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final String claimId = widget.claimId.trim();
    final String patientId = _patientId;

    if (claimId.isEmpty) return;

    if (patientId.isEmpty) {
      setState(() {
        _error = 'Patient ID is required to load this claim.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final InsuranceClaim? claim = await ref
          .read(insuranceClaimsControllerProvider.notifier)
          .get(patientId: patientId, claimId: claimId);

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
    final InsuranceClaim? claim = _claim;
    if (claim == null) return;

    final List<InsuranceMembership> loadedMemberships = ref
        .read(insuranceMembershipsControllerProvider)
        .items;

    final InsuranceClaimUpdateInput? input =
        await showDialog<InsuranceClaimUpdateInput>(
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

    final InsuranceClaim? updated = await ref
        .read(insuranceClaimsControllerProvider.notifier)
        .update(
          patientId: claim.patientId,
          claimId: claim.claimId,
          input: input,
        );

    if (!mounted) return;

    if (updated == null) {
      final String? error = ref.read(insuranceClaimsControllerProvider).error;

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

  Future<void> _replaceClaimDocument(InsuranceClaim claim) async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );

    if (!mounted || picked == null || picked.files.isEmpty) return;

    final PlatformFile file = picked.files.single;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read selected file.')),
      );
      return;
    }

    final InsuranceClaimsService svc = await ref.read(
      insuranceClaimsServiceProvider.future,
    );

    final UploadedInsuranceClaimFile uploaded = await svc.uploadClaimFile(
      patientId: claim.patientId,
      file: PickedInsuranceClaimFile(
        fileName: file.name,
        extension: file.extension ?? 'pdf',
        bytes: bytes,
      ),
    );

    if (!mounted) return;

    final InsuranceClaim? updated = await ref
        .read(insuranceClaimsControllerProvider.notifier)
        .update(
          patientId: claim.patientId,
          claimId: claim.claimId,
          input: InsuranceClaimUpdateInput(
            fileName: uploaded.fileName,
            storagePath: uploaded.storagePath,
            originalStoragePath: uploaded.originalStoragePath,
            thumbnailStoragePath: uploaded.thumbnailStoragePath,
            downloadUrl: uploaded.downloadUrl,
            contentType: uploaded.contentType,
            sizeBytes: uploaded.sizeBytes,
          ),
        );

    if (!mounted) return;

    if (updated == null) {
      final String? error = ref.read(insuranceClaimsControllerProvider).error;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to replace claim document')),
      );
      return;
    }

    setState(() => _claim = updated);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Claim document replaced')));
  }

  Future<void> _pickOrUploadPrescription(InsuranceClaim claim) async {
    final Prescription? picked = await showDialog<Prescription>(
      context: context,
      builder: (_) => _ClaimPrescriptionPickerDialog(claim: claim),
    );

    if (!mounted || picked == null) return;

    final InsuranceClaim? updated = await ref
        .read(insuranceClaimsControllerProvider.notifier)
        .update(
          patientId: claim.patientId,
          claimId: claim.claimId,
          input: InsuranceClaimUpdateInput(
            prescriptionId: picked.prescriptionId,
            prescriptionNo: claim.prescriptionNo,
            prescriberName: claim.prescriberName,
          ),
        );

    if (!mounted) return;

    if (updated == null) {
      final String? error = ref.read(insuranceClaimsControllerProvider).error;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to link prescription')),
      );
      return;
    }

    setState(() => _claim = updated);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Prescription linked')));
  }

  Future<void> _openPrescription(InsuranceClaim claim) async {
    final String patientId = claim.patientId.trim();
    final String prescriptionId = (claim.prescriptionId ?? '').trim();

    if (patientId.isEmpty || prescriptionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No prescription is linked.')),
      );
      return;
    }

    try {
      final PrescriptionsService service = ref.read(
        prescriptionsServiceProvider,
      );

      final Prescription prescription = await service.get(
        patientId: patientId,
        prescriptionId: prescriptionId,
      );

      final String url = (prescription.downloadUrl ?? '').trim().isNotEmpty
          ? prescription.downloadUrl!.trim()
          : await service.downloadUrl(prescription.storagePath);

      if (!mounted) return;

      await _openUrl(url);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open prescription: $e')),
      );
    }
  }

  Future<void> _openInvoicePdf(InsuranceClaim claim) async {
    final String invoiceId = (claim.invoiceId ?? '').trim();

    if (invoiceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoice is linked to this claim.')),
      );
      return;
    }

    await ref
        .read(invoiceActionControllerProvider)
        .viewPdf(context, invoiceId: invoiceId);
  }

  Future<void> _openUrl(String? value) async {
    final String raw = (value ?? '').trim();

    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document link available')),
      );
      return;
    }

    final Uri? uri = Uri.tryParse(raw);

    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid document link')));
      return;
    }

    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open document')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final InsuranceClaim? claim = _claim;

    final bool busy =
        _loading || ref.watch(insuranceClaimsControllerProvider).isSaving;

    return AppPage(
      title: claim == null
          ? 'Insurance Claim'
          : 'Claim · ${claim.claimNo ?? claim.invoiceNumber ?? claim.claimId}',
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
          children: <Widget>[
            if (_loading && claim == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorBanner(message: _error!)
            else if (claim == null)
              const _EmptyClaim()
            else ...<Widget>[
              _ClaimSummaryCard(claim: claim),
              const SizedBox(height: 12),
              _ClaimDocumentsCard(
                claim: claim,
                busy: busy,
                onOpenClaimDocument: () => _openUrl(claim.downloadUrl),
                onOpenPrescription: () => _openPrescription(claim),
                onOpenInvoicePdf: () => _openInvoicePdf(claim),
                onReplaceClaimDocument: () => _replaceClaimDocument(claim),
                onPickPrescription: () => _pickOrUploadPrescription(claim),
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
          children: <Widget>[
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
              children: <Widget>[
                Chip(label: Text('Status: ${claim.status.label}')),
                if (claim.hasFile) const Chip(label: Text('Document uploaded')),
                if (claim.hasPrescription)
                  const Chip(label: Text('Prescription linked')),
                if (claim.hasInvoice) const Chip(label: Text('Invoice linked')),
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
    required this.busy,
    required this.onOpenClaimDocument,
    required this.onOpenPrescription,
    required this.onOpenInvoicePdf,
    required this.onReplaceClaimDocument,
    required this.onPickPrescription,
  });

  final InsuranceClaim claim;
  final bool busy;
  final VoidCallback onOpenClaimDocument;
  final VoidCallback onOpenPrescription;
  final VoidCallback onOpenInvoicePdf;
  final VoidCallback onReplaceClaimDocument;
  final VoidCallback onPickPrescription;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            const _SectionTitle(
              icon: Icons.folder_outlined,
              title: 'Claim documents',
            ),
            const SizedBox(height: 12),
            _DocumentTile(
              title: 'Insurance claim document',
              subtitle: _claimDocumentSubtitle(claim),
              icon: Icons.assignment_outlined,
              hasLink: claim.hasFile,
              onOpen: onOpenClaimDocument,
              secondaryAction: TextButton.icon(
                onPressed: busy ? null : onReplaceClaimDocument,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Replace'),
              ),
            ),
            const Divider(height: 1),
            _DocumentTile(
              title: 'Prescription',
              subtitle: _prescriptionSubtitle(claim),
              icon: Icons.medication_outlined,
              hasLink: _hasText(claim.prescriptionId),
              onOpen: onOpenPrescription,
              secondaryAction: TextButton.icon(
                onPressed: busy ? null : onPickPrescription,
                icon: const Icon(Icons.medication_outlined),
                label: Text(claim.hasPrescription ? 'Change' : 'Pick / upload'),
              ),
            ),
            const Divider(height: 1),
            _DocumentTile(
              title: 'Invoice PDF',
              subtitle: claim.invoiceNumber ?? claim.invoiceId ?? 'Not linked',
              icon: Icons.receipt_long_outlined,
              hasLink: _hasText(claim.invoiceId),
              onOpen: onOpenInvoicePdf,
            ),
          ],
        ),
      ),
    );
  }

  static String _claimDocumentSubtitle(InsuranceClaim claim) {
    final List<String> parts = <String>[
      if (_hasText(claim.fileName)) claim.fileName.trim(),
      if (_hasText(claim.contentType)) claim.contentType!.trim(),
      if (claim.sizeBytes != null) _formatBytes(claim.sizeBytes!),
    ];

    return parts.isEmpty ? 'No document uploaded' : parts.join(' · ');
  }

  static String _prescriptionSubtitle(InsuranceClaim claim) {
    final List<String> parts = <String>[
      if (_hasText(claim.prescriptionNo)) 'Rx No: ${claim.prescriptionNo}',
      if (_hasText(claim.prescriptionId)) 'ID: ${claim.prescriptionId}',
    ];

    return parts.isEmpty ? 'Not linked' : parts.join(' · ');
  }

  static bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';

    final double kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';

    final double mb = kb / 1024;
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
          children: <Widget>[
            const _SectionTitle(
              icon: Icons.fact_check_outlined,
              title: 'Claim details',
            ),
            const SizedBox(height: 12),
            _InfoRow('Auth code', claim.authCode),
            _InfoRow('Claim no.', claim.claimNo),
            _InfoRow('Visit no.', claim.visitNo),
            _InfoRow('Service date', claim.serviceDate),
            _InfoRow('Prescription ID', claim.prescriptionId),
            _InfoRow('Prescription no.', claim.prescriptionNo),
            _InfoRow('Prescriber', claim.prescriberName),
            _InfoRow('Diagnosis', claim.diagnosis),
            _InfoRow('ICD-10', claim.icd10Code),
            _InfoRow('Notes', claim.notes),
            _InfoRow('Submitted at', claim.submittedAt),
            _InfoRow('Submitted by', claim.submittedByUid),
            _InfoRow('Uploaded by', claim.uploadedByUid),
            _InfoRow('Created', claim.createdAt),
            _InfoRow('Updated', claim.updatedAt),
          ],
        ),
      ),
    );
  }
}

class _ClaimPrescriptionPickerDialog extends ConsumerStatefulWidget {
  const _ClaimPrescriptionPickerDialog({required this.claim});

  final InsuranceClaim claim;

  @override
  ConsumerState<_ClaimPrescriptionPickerDialog> createState() =>
      _ClaimPrescriptionPickerDialogState();
}

class _ClaimPrescriptionPickerDialogState
    extends ConsumerState<_ClaimPrescriptionPickerDialog> {
  Prescription? _selected;

  String get _patientId => widget.claim.patientId.trim();

  @override
  void initState() {
    super.initState();

    Future<void>.microtask(_load);
  }

  Future<void> _load() {
    if (_patientId.isEmpty) return Future<void>.value();

    return ref
        .read(prescriptionsControllerProvider(_patientId).notifier)
        .load(patientId: _patientId, isActive: true);
  }

  Future<void> _upload() async {
    if (_patientId.isEmpty) {
      _snack('Claim patient ID is missing.');
      return;
    }

    final _PrescriptionUploadMeta? meta =
        await showDialog<_PrescriptionUploadMeta>(
          context: context,
          builder: (_) => const _PrescriptionUploadMetaDialog(),
        );

    if (!mounted || meta == null) return;

    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );

    if (!mounted || picked == null || picked.files.isEmpty) return;

    final PlatformFile file = picked.files.single;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      _snack('Could not read selected file.');
      return;
    }

    final String tenantId = ref.read(tenantIdProvider).trim();

    final PrescriptionsController controller = ref.read(
      prescriptionsControllerProvider(_patientId).notifier,
    );

    await controller.upload(
      tenantId: tenantId,
      patientId: _patientId,
      file: PickedPrescriptionFile(
        fileName: file.name,
        extension: file.extension ?? 'jpg',
        bytes: bytes,
      ),
      note: meta.note,
      prescribedOn: meta.prescribedOn,
    );

    if (!mounted) return;

    final PrescriptionsState state = ref.read(
      prescriptionsControllerProvider(_patientId),
    );

    if (state.error != null) {
      _snack(state.error!);
      return;
    }

    final Prescription? saved = state.items.isEmpty ? null : state.items.first;

    setState(() => _selected = saved);

    _snack('Prescription uploaded.');
  }

  void _useSelected() {
    final Prescription? selected = _selected;

    if (selected == null) {
      _snack('Pick or upload a prescription first.');
      return;
    }

    Navigator.of(context).pop(selected);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final PrescriptionsState state = _patientId.isEmpty
        ? const PrescriptionsState()
        : ref.watch(prescriptionsControllerProvider(_patientId));

    return AlertDialog(
      title: const Text('Link prescription'),
      content: SizedBox(
        width: 720,
        height: MediaQuery.of(context).size.height * 0.66,
        child: PrescriptionPickerCard(
          patientId: _patientId,
          prescriptions: state.items,
          selectedPrescriptionId:
              _selected?.prescriptionId ?? widget.claim.prescriptionId,
          busy: state.busy,
          error: state.error,
          requiredForClaim: true,
          onRefresh: _patientId.isEmpty ? null : _load,
          onUpload: _patientId.isEmpty ? null : _upload,
          onChanged: (Prescription? prescription) {
            setState(() => _selected = prescription);
          },
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(null),
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: state.busy ? null : _useSelected,
          icon: const Icon(Icons.check),
          label: const Text('Link'),
        ),
      ],
    );
  }
}

class _PrescriptionUploadMeta {
  const _PrescriptionUploadMeta({this.note, this.prescribedOn});

  final String? note;
  final String? prescribedOn;
}

class _PrescriptionUploadMetaDialog extends StatefulWidget {
  const _PrescriptionUploadMetaDialog();

  @override
  State<_PrescriptionUploadMetaDialog> createState() =>
      _PrescriptionUploadMetaDialogState();
}

class _PrescriptionUploadMetaDialogState
    extends State<_PrescriptionUploadMetaDialog> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _prescribedOnController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _prescribedOnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Prescription details'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _prescribedOnController,
              decoration: const InputDecoration(
                labelText: 'Prescribed on',
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            final String? prescribedOn = _clean(_prescribedOnController.text);

            if (prescribedOn != null &&
                !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(prescribedOn)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Date must be YYYY-MM-DD')),
              );
              return;
            }

            Navigator.of(context).pop(
              _PrescriptionUploadMeta(
                note: _clean(_noteController.text),
                prescribedOn: prescribedOn,
              ),
            );
          },
          icon: const Icon(Icons.check),
          label: const Text('Continue'),
        ),
      ],
    );
  }

  String? _clean(String value) {
    final String clean = value.trim();
    return clean.isEmpty ? null : clean;
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (secondaryAction != null) secondaryAction!,
          IconButton(
            tooltip: 'Open',
            onPressed: hasLink ? onOpen : null,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
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
    final String clean = (value ?? '').trim();

    if (clean.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(clean)),
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
