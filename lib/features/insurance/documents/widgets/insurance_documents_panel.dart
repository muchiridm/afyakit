import 'package:afyakit/features/insurance/documents/controllers/insurance_documents_controller.dart';
import 'package:afyakit/features/insurance/documents/models/insurance_document.dart';
import 'package:afyakit/features/insurance/documents/services/insurance_documents_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class InsuranceDocumentsPanel extends ConsumerStatefulWidget {
  const InsuranceDocumentsPanel({
    super.key,
    required this.patientId,
    this.claimPackId,
    this.membershipId,
    this.payerContactId,
    this.payerDisplayName,
    this.title = 'Documents',
    this.emptyText = 'No documents uploaded.',
    this.showUploadActions = true,
  });

  final String patientId;
  final String? claimPackId;
  final String? membershipId;
  final String? payerContactId;
  final String? payerDisplayName;

  final String title;
  final String emptyText;
  final bool showUploadActions;

  @override
  ConsumerState<InsuranceDocumentsPanel> createState() =>
      _InsuranceDocumentsPanelState();
}

class _InsuranceDocumentsPanelState
    extends ConsumerState<InsuranceDocumentsPanel> {
  String get _patientId => widget.patientId.trim();

  String? get _claimPackId {
    final String id = (widget.claimPackId ?? '').trim();
    return id.isEmpty ? null : id;
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant InsuranceDocumentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool changed =
        oldWidget.patientId.trim() != widget.patientId.trim() ||
        (oldWidget.claimPackId ?? '').trim() !=
            (widget.claimPackId ?? '').trim();

    if (changed) {
      Future<void>.microtask(_load);
    }
  }

  Future<void> _load() {
    if (_patientId.isEmpty) return Future<void>.value();

    final InsuranceDocumentsController controller = ref.read(
      insuranceDocumentsControllerProvider.notifier,
    );

    final String? claimPackId = _claimPackId;

    if (claimPackId != null) {
      return controller.loadForClaimPack(
        patientId: _patientId,
        claimPackId: claimPackId,
        perPage: 100,
        page: 1,
      );
    }

    return controller.loadForPatient(
      patientId: _patientId,
      isActive: true,
      perPage: 100,
      page: 1,
    );
  }

  Future<void> _upload(InsuranceDocumentType type) async {
    if (_patientId.isEmpty) {
      _snack('Patient ID is missing.');
      return;
    }

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

    final InsuranceDocument? document = await ref
        .read(insuranceDocumentsControllerProvider.notifier)
        .uploadDocumentFileAndCreate(
          patientId: _patientId,
          claimPackId: _claimPackId,
          membershipId: _cleanOrNull(widget.membershipId),
          payerContactId: _cleanOrNull(widget.payerContactId),
          payerDisplayName: _cleanOrNull(widget.payerDisplayName),
          documentType: type,
          file: PickedInsuranceDocumentFile(
            fileName: file.name,
            extension: file.extension ?? 'pdf',
            bytes: bytes,
          ),
          title: type.label,
        );

    if (!mounted) return;

    if (document == null) {
      final String? error = ref
          .read(insuranceDocumentsControllerProvider)
          .error;
      _snack(error ?? 'Failed to upload document.');
      return;
    }

    _snack('Document uploaded.');
  }

  Future<void> _archive(InsuranceDocument document) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive document?'),
        content: Text(
          'This will archive ${document.title ?? document.fileName}. The file record remains for audit history.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final bool ok = await ref
        .read(insuranceDocumentsControllerProvider.notifier)
        .delete(patientId: document.patientId, documentId: document.documentId);

    if (!mounted) return;

    if (!ok) {
      final String? error = ref
          .read(insuranceDocumentsControllerProvider)
          .error;
      _snack(error ?? 'Failed to archive document.');
      return;
    }

    _snack('Document archived.');
  }

  Future<void> _open(InsuranceDocument document) async {
    final String url = (document.downloadUrl ?? '').trim();

    if (url.isEmpty) {
      _snack('No document link available.');
      return;
    }

    final Uri? uri = Uri.tryParse(url);

    if (uri == null) {
      _snack('Invalid document link.');
      return;
    }

    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && mounted) {
      _snack('Could not open document.');
    }
  }

  List<InsuranceDocument> _visibleDocuments(List<InsuranceDocument> items) {
    final String? claimPackId = _claimPackId;

    return items
        .where((InsuranceDocument document) {
          if (!document.isActive) return false;
          if (document.patientId.trim() != _patientId) return false;

          if (claimPackId != null) {
            return (document.claimPackId ?? '').trim() == claimPackId;
          }

          return true;
        })
        .toList(growable: false);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _cleanOrNull(String? value) {
    final String clean = (value ?? '').trim();
    return clean.isEmpty ? null : clean;
  }

  @override
  Widget build(BuildContext context) {
    final InsuranceDocumentsState state = ref.watch(
      insuranceDocumentsControllerProvider,
    );

    final List<InsuranceDocument> documents = _visibleDocuments(state.items);

    final List<InsuranceDocument> claimForms = documents
        .where(
          (InsuranceDocument document) =>
              document.documentType == InsuranceDocumentType.claimForm,
        )
        .toList(growable: false);

    final List<InsuranceDocument> supportingDocuments = documents
        .where(
          (InsuranceDocument document) =>
              document.documentType != InsuranceDocumentType.claimForm,
        )
        .toList(growable: false);

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _PanelHeader(
              title: widget.title,
              count: documents.length,
              isLoading: state.isLoading,
              onRefresh: _load,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 8),
              _ErrorText(state.error!),
            ],
            const SizedBox(height: 12),
            _DocumentGroup(
              title: 'Claim form',
              documents: claimForms,
              emptyText: 'No claim form uploaded.',
              isSaving: state.isSaving,
              showUploadAction: widget.showUploadActions,
              uploadLabel: claimForms.isEmpty ? 'Upload' : 'Upload another',
              onUpload: () => _upload(InsuranceDocumentType.claimForm),
              onOpen: _open,
              onArchive: _archive,
            ),
            const Divider(height: 28),
            _DocumentGroup(
              title: 'Supporting documents',
              documents: supportingDocuments,
              emptyText: widget.emptyText,
              isSaving: state.isSaving,
              showUploadAction: widget.showUploadActions,
              uploadLabel: 'Upload',
              onUpload: () => _upload(InsuranceDocumentType.other),
              onOpen: _open,
              onArchive: _archive,
            ),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.count,
    required this.isLoading,
    required this.onRefresh,
  });

  final String title;
  final int count;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        const CircleAvatar(child: Icon(Icons.folder_outlined)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                count == 1
                    ? '1 document attached.'
                    : '$count documents attached.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh documents',
          onPressed: isLoading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _DocumentGroup extends StatelessWidget {
  const _DocumentGroup({
    required this.title,
    required this.documents,
    required this.emptyText,
    required this.isSaving,
    required this.showUploadAction,
    required this.uploadLabel,
    required this.onUpload,
    required this.onOpen,
    required this.onArchive,
  });

  final String title;
  final List<InsuranceDocument> documents;
  final String emptyText;
  final bool isSaving;
  final bool showUploadAction;
  final String uploadLabel;
  final VoidCallback onUpload;
  final ValueChanged<InsuranceDocument> onOpen;
  final ValueChanged<InsuranceDocument> onArchive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (showUploadAction)
              TextButton.icon(
                onPressed: isSaving ? null : onUpload,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(uploadLabel),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (documents.isEmpty)
          _EmptyDocumentsText(text: emptyText)
        else
          ...documents.map(
            (InsuranceDocument document) => _DocumentTile(
              document: document,
              onOpen: () => onOpen(document),
              onArchive: () => onArchive(document),
            ),
          ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.onOpen,
    required this.onArchive,
  });

  final InsuranceDocument document;
  final VoidCallback onOpen;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final bool hasLink = (document.downloadUrl ?? '').trim().isNotEmpty;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_iconFor(document)),
      title: Text(
        document.title ?? document.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _subtitle(document),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 4,
        children: <Widget>[
          TextButton.icon(
            onPressed: hasLink ? onOpen : null,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
          ),
          IconButton(
            tooltip: 'Archive document',
            onPressed: onArchive,
            icon: const Icon(Icons.archive_outlined),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(InsuranceDocument document) {
    switch (document.documentType) {
      case InsuranceDocumentType.claimForm:
        return Icons.assignment_outlined;
      case InsuranceDocumentType.membershipCard:
        return Icons.badge_outlined;
      case InsuranceDocumentType.authorization:
        return Icons.verified_user_outlined;
      case InsuranceDocumentType.labResult:
        return Icons.science_outlined;
      case InsuranceDocumentType.dischargeSummary:
        return Icons.summarize_outlined;
      case InsuranceDocumentType.other:
        return Icons.insert_drive_file_outlined;
    }
  }

  static String _subtitle(InsuranceDocument document) {
    final List<String> parts = <String>[
      document.documentType.label,
      document.status.label,
      if ((document.contentType ?? '').trim().isNotEmpty)
        document.contentType!.trim(),
      if (document.sizeBytes != null) _formatBytes(document.sizeBytes!),
      if ((document.createdAt ?? '').trim().isNotEmpty)
        'Uploaded ${document.createdAt}',
    ];

    return parts.join(' · ');
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';

    final double kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';

    final double mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class _EmptyDocumentsText extends StatelessWidget {
  const _EmptyDocumentsText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.insert_drive_file_outlined),
      title: Text(text),
      subtitle: const Text('Upload a file to attach it here.'),
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
