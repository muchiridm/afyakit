import 'package:afyakit/core/files/private_file_dialog.dart';
// lib/features/clinical/prescriptions/widgets/prescriptions_screen.dart

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_picker.dart';
import 'package:afyakit/features/clinical/prescriptions/prescriptions_controller.dart';
import 'package:afyakit/features/clinical/prescriptions/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/prescriptions_providers.dart';
import 'package:afyakit/features/clinical/prescriptions/prescriptions_service.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({
    super.key,
    this.profileId,
    this.initialProfile,
    this.contactId,
    this.forceProfilePickerMode = false,
  });

  final String? profileId;
  final Profile? initialProfile;

  /// Member/contact scope for profile selection.
  final String? contactId;

  /// Staff/admin escape hatch. True searches all profiles.
  final bool forceProfilePickerMode;

  static Future<void> open({
    required BuildContext context,
    String? contactId,
    bool forceProfilePickerMode = false,
    Profile? profile,
  }) async {
    final selectedProfile =
        profile ??
        await showProfilePickerScreen(
          context: context,
          accountNumber: contactId,
          forcePickerMode: forceProfilePickerMode,
        );

    if (selectedProfile == null || !context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PrescriptionsScreen(
          profileId: selectedProfile.profileId,
          initialProfile: selectedProfile,
          contactId: forceProfilePickerMode ? null : contactId,
          forceProfilePickerMode: forceProfilePickerMode,
        ),
      ),
    );
  }

  @override
  ConsumerState<PrescriptionsScreen> createState() {
    return _PrescriptionsScreenState();
  }
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen> {
  Profile? _selectedProfile;

  String? get _fixedProfileId {
    final value = (widget.profileId ?? '').trim();
    return value.isEmpty ? null : value;
  }

  String? get _profileId {
    final fixedProfileId = _fixedProfileId;
    if (fixedProfileId != null) return fixedProfileId;

    final selectedProfileId = (_selectedProfile?.profileId ?? '').trim();
    return selectedProfileId.isEmpty ? null : selectedProfileId;
  }

  bool get _fixedToProfile => _fixedProfileId != null;

  String get _title {
    final profile = _selectedProfile;

    if (profile != null) {
      return 'Prescriptions · ${profile.fullName}';
    }

    if (_fixedToProfile) {
      return 'Profile Prescriptions';
    }

    return 'Prescriptions';
  }

  @override
  void initState() {
    super.initState();

    _selectedProfile = widget.initialProfile;

    final profile = _selectedProfile;

    if (profile == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref
          .read(prescriptionsControllerProvider(profile.profileId).notifier)
          .load(profileId: profile.profileId);
    });
  }

  @override
  void didUpdateWidget(covariant PrescriptionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldProfileId = oldWidget.initialProfile?.profileId;
    final newProfileId = widget.initialProfile?.profileId;

    if (oldProfileId == newProfileId) return;

    _selectedProfile = widget.initialProfile;

    final profile = _selectedProfile;

    if (profile == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref
          .read(prescriptionsControllerProvider(profile.profileId).notifier)
          .load(profileId: profile.profileId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileId = _profileId;

    final provider = profileId == null
        ? null
        : prescriptionsControllerProvider(profileId);

    final state = provider == null ? null : ref.watch(provider);
    final controller = provider == null ? null : ref.read(provider.notifier);

    final busy = state?.busy ?? false;
    final access = profileId == null
        ? <String>[]
        : ref.watch(prescriptionAccessProvider(profileId)).valueOrNull ??
              <String>[];
    final canUpload = access.contains('upload');
    final canUsePrescriptions = profileId != null && controller != null;

    final children = <Widget>[
      if (!_fixedToProfile || _selectedProfile != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: ProfilePickerCard(
            selectedProfile: _selectedProfile,
            busy: busy,
            accountNumber: widget.contactId,
            forcePickerMode: widget.forceProfilePickerMode,
            canChange: !_fixedToProfile,
            onChanged: _selectProfile,
          ),
        ),
      if (!canUsePrescriptions)
        const _PickProfilePrompt()
      else ...[
        if (state!.error != null && state.error!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    (prescription) => Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: _PrescriptionTile(
                        prescription: prescription,
                        busy: state.busy,
                        onOpen: () => _openPrescription(
                          context: context,
                          controller: controller,
                          prescription: prescription,
                        ),
                        onChangeStatus: () => _changeStatus(
                          context: context,
                          controller: controller,
                          prescription: prescription,
                        ),
                        onDelete: () => _confirmDelete(
                          context: context,
                          controller: controller,
                          prescription: prescription,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
      ],
    ];

    final list = ListView(padding: EdgeInsets.zero, children: children);

    return AppPage(
      title: _title,
      showBack: true,
      maxWidth: AppLayout.contentMaxWidth,
      padding: AppLayout.pagePadding,
      scrollable: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: !canUsePrescriptions || busy
              ? null
              : () => controller.load(profileId: profileId),
          icon: const Icon(Icons.refresh),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: !canUsePrescriptions || !canUpload || busy
                ? null
                : () =>
                      _pickAndUpload(context: context, controller: controller),
            icon: state?.isUploading == true
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
      body: canUsePrescriptions
          ? RefreshIndicator(
              onRefresh: () => controller.load(profileId: profileId),
              child: list,
            )
          : list,
    );
  }

  void _selectProfile(Profile profile) {
    if (profile.profileId == _selectedProfile?.profileId) return;

    setState(() {
      _selectedProfile = profile;
    });

    ref
        .read(prescriptionsControllerProvider(profile.profileId).notifier)
        .load(profileId: profile.profileId);
  }

  Future<void> _pickAndUpload({
    required BuildContext context,
    required PrescriptionsController controller,
  }) async {
    final profileId = _profileId;

    if (profileId == null) {
      _showSnack(context, 'Select a profile first.');
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

    await controller.upload(
      tenantId: tenantId,
      profileId: profileId,
      file: PickedPrescriptionFile(
        fileName: file.name,
        extension: file.extension ?? 'jpg',
        bytes: bytes,
      ),
      note: meta.note,
      prescribedOn: meta.prescribedOn,
    );

    if (!context.mounted) return;

    final error = ref.read(prescriptionsControllerProvider(profileId)).error;
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
      final file = await controller.download(prescription);

      if (!context.mounted) return;

      await showPrivateFile(context, file);
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, error.toString());
    }
  }

  Future<void> _changeStatus({
    required BuildContext context,
    required PrescriptionsController controller,
    required Prescription prescription,
  }) async {
    final nextStatus = await showDialog<PrescriptionStatus>(
      context: context,
      builder: (_) => _PrescriptionStatusDialog(
        currentStatus: prescription.status,
        allowed: prescription.allowedStatuses,
      ),
    );

    if (!context.mounted || nextStatus == null) return;

    if (nextStatus == prescription.status) {
      _showSnack(context, 'Prescription status unchanged.');
      return;
    }

    final updated = await controller.update(
      prescription: prescription,
      input: PrescriptionUpdateInput(status: nextStatus),
    );

    if (!context.mounted) return;

    if (updated == null) {
      final error = ref
          .read(prescriptionsControllerProvider(prescription.profileId))
          .error;

      _showSnack(context, error ?? 'Failed to update prescription status.');
      return;
    }

    _showSnack(context, 'Prescription marked as ${nextStatus.label}.');
  }

  Future<void> _confirmDelete({
    required BuildContext context,
    required PrescriptionsController controller,
    required Prescription prescription,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive prescription?'),
        content: const Text(
          'This removes the prescription from ordinary workflows. Original evidence and historical associations are retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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

class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({
    required this.prescription,
    required this.busy,
    required this.onOpen,
    required this.onChangeStatus,
    required this.onDelete,
  });

  final Prescription prescription;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onChangeStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(_iconFor(prescription))),
        title: Text(
          prescription.fileName.isEmpty
              ? prescription.prescriptionId
              : prescription.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              'Patient: ${prescription.profileId}',
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
        trailing: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _PrescriptionStatusChip(status: prescription.status),
            PopupMenuButton<_PrescriptionAction>(
              enabled: !busy,
              onSelected: (action) {
                switch (action) {
                  case _PrescriptionAction.open:
                    onOpen();
                    break;
                  case _PrescriptionAction.changeStatus:
                    onChangeStatus();
                    break;
                  case _PrescriptionAction.delete:
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                if (prescription.can('read'))
                  const PopupMenuItem(
                    value: _PrescriptionAction.open,
                    child: ListTile(
                      leading: Icon(Icons.open_in_new),
                      title: Text('Open'),
                    ),
                  ),
                if (prescription.can('review'))
                  const PopupMenuItem(
                    value: _PrescriptionAction.changeStatus,
                    child: ListTile(
                      leading: Icon(Icons.fact_check_outlined),
                      title: Text('Change status'),
                    ),
                  ),
                if (prescription.can('archive'))
                  const PopupMenuItem(
                    value: _PrescriptionAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Archive'),
                    ),
                  ),
              ],
            ),
          ],
        ),
        onTap: busy || !prescription.can('read') ? null : onOpen,
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

class _PrescriptionStatusChip extends StatelessWidget {
  const _PrescriptionStatusChip({required this.status});

  final PrescriptionStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.label),
      avatar: Icon(_iconFor(status), size: 18),
      visualDensity: VisualDensity.compact,
    );
  }

  static IconData _iconFor(PrescriptionStatus status) {
    switch (status) {
      case PrescriptionStatus.uploaded:
        return Icons.cloud_upload_outlined;
      case PrescriptionStatus.pendingReview:
        return Icons.pending_actions_outlined;
      case PrescriptionStatus.verified:
        return Icons.verified_outlined;
      case PrescriptionStatus.rejected:
        return Icons.block_outlined;
      case PrescriptionStatus.used:
        return Icons.task_alt_outlined;
      case PrescriptionStatus.expired:
        return Icons.event_busy_outlined;
    }
  }
}

class _PrescriptionStatusDialog extends StatefulWidget {
  const _PrescriptionStatusDialog({
    required this.currentStatus,
    required this.allowed,
  });
  final List<PrescriptionStatus> allowed;

  final PrescriptionStatus currentStatus;

  @override
  State<_PrescriptionStatusDialog> createState() =>
      _PrescriptionStatusDialogState();
}

class _PrescriptionStatusDialogState extends State<_PrescriptionStatusDialog> {
  late PrescriptionStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.allowed.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change prescription status'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.allowed
              .map((status) {
                return RadioListTile<PrescriptionStatus>(
                  value: status,
                  groupValue: _selectedStatus,
                  title: Text(status.label),
                  subtitle: Text(_descriptionFor(status)),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedStatus = value);
                  },
                );
              })
              .toList(growable: false),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _selectedStatus),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save status'),
        ),
      ],
    );
  }

  static String _descriptionFor(PrescriptionStatus status) {
    switch (status) {
      case PrescriptionStatus.uploaded:
        return 'Uploaded by patient/member or staff, not yet reviewed.';
      case PrescriptionStatus.pendingReview:
        return 'Queued for pharmacist/admin review.';
      case PrescriptionStatus.verified:
        return 'Approved for use in dispensing or insurance claims.';
      case PrescriptionStatus.rejected:
        return 'Rejected after review.';
      case PrescriptionStatus.used:
        return 'Already used for fulfilment or claim processing.';
      case PrescriptionStatus.expired:
        return 'No longer valid for use.';
    }
  }
}

enum _PrescriptionAction { open, changeStatus, delete }

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

class _PickProfilePrompt extends StatelessWidget {
  const _PickProfilePrompt();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Text(
          'Select a profile to view or upload prescriptions.',
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
