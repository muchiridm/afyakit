// lib/features/clinical/prescriptions/widgets/prescriptions_screen.dart

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/prescriptions/controllers/prescriptions_controller.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_picker.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/providers/prescriptions_providers.dart';
import 'package:afyakit/features/clinical/prescriptions/services/prescriptions_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({
    super.key,
    this.patientId,
    this.initialPatient,
    this.contactId,
    this.forcePatientPickerMode = false,
  });

  final String? patientId;
  final PatientProfile? initialPatient;

  /// Member/contact scope for patient picker.
  final String? contactId;

  /// Staff/admin escape hatch. True means picker searches all patients.
  final bool forcePatientPickerMode;

  @override
  ConsumerState<PrescriptionsScreen> createState() =>
      _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen> {
  PatientProfile? _selectedPatient;
  String? _selectedPatientId;

  double get _maxWidth => AppLayout.contentMaxWidth;

  String? get _patientId {
    final fromWidget = (widget.patientId ?? '').trim();
    if (fromWidget.isNotEmpty) return fromWidget;

    final fromSelected = (_selectedPatient?.patientId ?? '').trim();
    if (fromSelected.isNotEmpty) return fromSelected;

    final fromId = (_selectedPatientId ?? '').trim();
    return fromId.isEmpty ? null : fromId;
  }

  String get _title {
    final patient = _selectedPatient;
    final fixedPatientId = (widget.patientId ?? '').trim();

    if (patient != null) return 'Prescriptions · ${patient.fullName}';
    if (fixedPatientId.isNotEmpty) return 'Patient Prescriptions';

    return 'Prescriptions';
  }

  @override
  void initState() {
    super.initState();

    _selectedPatient = widget.initialPatient;

    final fixedPatientId = (widget.patientId ?? '').trim();
    if (fixedPatientId.isNotEmpty) {
      _selectedPatientId = fixedPatientId;
    } else {
      _selectedPatientId = widget.initialPatient?.patientId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientId = _patientId;
    final fixedToPatient = (widget.patientId ?? '').trim().isNotEmpty;

    if (patientId == null || patientId.trim().isEmpty) {
      return AppPage(
        title: _title,
        showBack: true,
        maxWidth: _maxWidth,
        padding: AppLayout.pagePadding,
        scrollable: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: null,
            icon: const Icon(Icons.refresh),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload prescription'),
            ),
          ),
        ],
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (!fixedToPatient)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: PatientPickerCard(
                  selectedPatient: _selectedPatient,
                  busy: false,
                  contactId: widget.contactId,
                  forcePickerMode: widget.forcePatientPickerMode,
                  onChanged: (patient) {
                    setState(() {
                      _selectedPatient = patient;
                      _selectedPatientId = patient.patientId;
                    });
                  },
                ),
              ),
            const _PickPatientPrompt(),
          ],
        ),
      );
    }

    final provider = prescriptionsControllerProvider(patientId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    final canUpload = patientId.trim().isNotEmpty;

    return AppPage(
      title: _title,
      showBack: true,
      maxWidth: _maxWidth,
      padding: AppLayout.pagePadding,
      scrollable: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: state.busy || !canUpload
              ? null
              : () => controller.load(patientId: _patientId),
          icon: const Icon(Icons.refresh),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: state.busy || !canUpload
                ? null
                : () =>
                      _pickAndUpload(context: context, controller: controller),
            icon: state.isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: const Text('Upload prescription'),
          ),
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => controller.load(patientId: _patientId),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (!fixedToPatient) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: PatientPickerCard(
                        selectedPatient: _selectedPatient,
                        busy: state.busy,
                        contactId: widget.contactId,
                        forcePickerMode: widget.forcePatientPickerMode,
                        onChanged: (patient) {
                          setState(() {
                            _selectedPatient = patient;
                            _selectedPatientId = patient.patientId;
                          });

                          ref
                              .read(
                                prescriptionsControllerProvider(
                                  patient.patientId,
                                ).notifier,
                              )
                              .load(patientId: patient.patientId);
                        },
                      ),
                    ),
                  ] else if (_selectedPatient != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _SelectedPatientHeader(patient: _selectedPatient!),
                    ),
                  ],

                  if (state.error != null && state.error!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: _ErrorBanner(message: state.error!),
                    ),

                  if (state.isLoading && state.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.items.isEmpty)
                    const _EmptyPrescriptions()
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: state.items
                            .map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  bottom: 8,
                                ),
                                child: _PrescriptionTile(
                                  prescription: p,
                                  onOpen: () => _openPrescription(
                                    context: context,
                                    controller: controller,
                                    prescription: p,
                                  ),
                                  onDelete: () => _confirmDelete(
                                    context: context,
                                    controller: controller,
                                    prescription: p,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
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

  Future<void> _pickAndUpload({
    required BuildContext context,
    required PrescriptionsController controller,
  }) async {
    final patientId = _patientId;

    if (patientId == null || patientId.trim().isEmpty) {
      _showSnack(context, 'Pick a patient first.');
      return;
    }

    final tenantId = ref.read(tenantIdProvider).trim();

    final meta = await showDialog<_PrescriptionUploadMeta>(
      context: context,
      builder: (context) => const _PrescriptionMetaDialog(),
    );

    if (!context.mounted || meta == null) return;

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );

    if (!context.mounted || picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      _showSnack(context, 'Could not read selected file.');
      return;
    }

    final pickedFile = PickedPrescriptionFile(
      fileName: file.name,
      extension: file.extension ?? 'jpg',
      bytes: bytes,
    );

    await controller.upload(
      tenantId: tenantId,
      patientId: patientId,
      file: pickedFile,
      note: meta.note,
      prescribedOn: meta.prescribedOn,
    );

    if (!context.mounted) return;

    final error = ref.read(prescriptionsControllerProvider(patientId)).error;
    if (error == null) {
      _showSnack(context, 'Prescription uploaded.');
    }
  }

  Future<void> _openPrescription({
    required BuildContext context,
    required PrescriptionsController controller,
    required Prescription prescription,
  }) async {
    try {
      final url = await controller.downloadUrl(prescription);

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) =>
            _PrescriptionPreviewDialog(prescription: prescription, url: url),
      );
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, e.toString());
    }
  }

  Future<void> _confirmDelete({
    required BuildContext context,
    required PrescriptionsController controller,
    required Prescription prescription,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete prescription?'),
        content: const Text(
          'This removes the prescription record. The uploaded Storage file is not deleted by this MVP action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await controller.delete(prescription);

    if (!context.mounted) return;
    _showSnack(context, 'Prescription deleted.');
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SelectedPatientHeader extends StatelessWidget {
  const _SelectedPatientHeader({required this.patient});

  final PatientProfile patient;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(
          patient.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            patient.patientId,
            if ((patient.dob ?? '').trim().isNotEmpty) 'DOB: ${patient.dob}',
            if ((patient.phone ?? '').trim().isNotEmpty) patient.phone,
          ].join(' • '),
        ),
      ),
    );
  }
}

class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({
    required this.prescription,
    required this.onOpen,
    required this.onDelete,
  });

  final Prescription prescription;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(_iconFor(prescription))),
        title: Text(
          prescription.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              'Patient: ${prescription.patientId}',
              'Status: ${prescription.status.label}',
              if (prescription.prescribedOn != null)
                'Prescribed: ${prescription.prescribedOn}',
              if (prescription.sizeBytes != null)
                'Size: ${_formatBytes(prescription.sizeBytes!)}',
              if ((prescription.note ?? '').trim().isNotEmpty)
                'Note: ${prescription.note}',
            ].join('\n'),
            style: theme.textTheme.bodySmall,
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<_PrescriptionAction>(
          onSelected: (action) {
            switch (action) {
              case _PrescriptionAction.open:
                onOpen();
                break;
              case _PrescriptionAction.delete:
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _PrescriptionAction.open,
              child: ListTile(
                leading: Icon(Icons.open_in_new),
                title: Text('Open'),
              ),
            ),
            PopupMenuItem(
              value: _PrescriptionAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Delete'),
              ),
            ),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }

  static IconData _iconFor(Prescription p) {
    final type = (p.contentType ?? '').toLowerCase();
    if (type.contains('pdf')) return Icons.picture_as_pdf_outlined;
    return Icons.image_outlined;
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';

    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';

    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

enum _PrescriptionAction { open, delete }

class _PrescriptionUploadMeta {
  const _PrescriptionUploadMeta({this.note, this.prescribedOn});

  final String? note;
  final String? prescribedOn;
}

class _PrescriptionMetaDialog extends StatefulWidget {
  const _PrescriptionMetaDialog();

  @override
  State<_PrescriptionMetaDialog> createState() =>
      _PrescriptionMetaDialogState();
}

class _PrescriptionMetaDialogState extends State<_PrescriptionMetaDialog> {
  final _noteController = TextEditingController();
  final _prescribedOnController = TextEditingController();

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
          children: [
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            final prescribedOn = _clean(_prescribedOnController.text);

            if (prescribedOn != null &&
                !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(prescribedOn)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Date must be YYYY-MM-DD')),
              );
              return;
            }

            Navigator.pop(
              context,
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
    final s = value.trim();
    return s.isEmpty ? null : s;
  }
}

class _PrescriptionPreviewDialog extends StatelessWidget {
  const _PrescriptionPreviewDialog({
    required this.prescription,
    required this.url,
  });

  final Prescription prescription;
  final String url;

  bool get _isPdf {
    final type = (prescription.contentType ?? '').toLowerCase();
    final name = prescription.fileName.toLowerCase();
    return type.contains('pdf') || name.endsWith('.pdf');
  }

  bool get _isImage {
    final type = (prescription.contentType ?? '').toLowerCase();
    final name = prescription.fileName.toLowerCase();

    return type.startsWith('image/') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp');
  }

  Future<void> _openExternal(BuildContext context) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid prescription URL')));
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open prescription')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = prescription.fileName.trim().isEmpty
        ? 'Prescription'
        : prescription.fileName.trim();

    return AlertDialog(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 720,
        height: 520,
        child: _isImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;

                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _PrescriptionPreviewFallback(
                        icon: Icons.broken_image_outlined,
                        title: 'Could not preview image',
                        subtitle: 'Use Open to view the prescription.',
                        onOpen: () => _openExternal(context),
                      );
                    },
                  ),
                ),
              )
            : _PrescriptionPreviewFallback(
                icon: _isPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.description_outlined,
                title: _isPdf ? 'PDF prescription' : 'Prescription file',
                subtitle: 'Use Open to view the file.',
                onOpen: () => _openExternal(context),
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _openExternal(context),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _PrescriptionPreviewFallback extends StatelessWidget {
  const _PrescriptionPreviewFallback({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onOpen,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open file'),
            ),
          ],
        ),
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
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickPatientPrompt extends StatelessWidget {
  const _PickPatientPrompt();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Text(
          'Pick a patient to view or upload prescriptions.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptyPrescriptions extends StatelessWidget {
  const _EmptyPrescriptions();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Text('No prescriptions found.', textAlign: TextAlign.center),
      ),
    );
  }
}
