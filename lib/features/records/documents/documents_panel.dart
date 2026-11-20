import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'document_model.dart';
import 'document_upload_service.dart';
import 'documents_controller.dart';
import 'documents_service.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

/// Generic profile document panel. The host supplies staff capability from its
/// existing authorization state. The backend remains the authority.
class DocumentsPanel extends ConsumerStatefulWidget {
  const DocumentsPanel({
    super.key,
    required this.profileId,
    this.canManage = false,
    this.showUploadActions = true,
    this.title = 'Documents',
    this.emptyText = 'No documents uploaded.',
  });
  final String profileId, title, emptyText;
  final bool canManage, showUploadActions;
  @override
  ConsumerState<DocumentsPanel> createState() => _DocumentsPanelState();
}

class _DocumentsPanelState extends ConsumerState<DocumentsPanel> {
  int _page = 1;
  bool _active = true, _busy = false;
  DocumentFinalizationException? _pending;
  DocumentsService? _pendingService;
  DocumentsQuery get _query =>
      (profileId: widget.profileId, page: _page, isActive: _active);

  @override
  void didUpdateWidget(covariant DocumentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      _page = 1;
      _active = true;
      _pending = null;
      _pendingService = null;
    }
  }

  void _message(String message) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(
    Future<void> Function(DocumentsService service) action,
  ) async {
    if (_busy) return;
    final query = _query;
    setState(() => _busy = true);
    try {
      final service = await ref.read(documentsServiceProvider.future);
      if (!mounted || widget.profileId != query.profileId) return;
      await action(service);
    } catch (_) {
      _message(
        'Document action failed. Check access and connectivity, then retry.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    if (!mounted) return;
    // Invalidate all pages, not just the currently displayed page.
    ref.invalidate(documentsControllerProvider);
  }

  Future<void> _upload() => _run((service) async {
    final profileId = widget.profileId;
    final canManage = widget.canManage;
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (!mounted || picked == null || !_sameScope(service, profileId)) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _message('Could not read the selected file.');
      return;
    }
    final selected = PickedDocumentFile(
      fileName: file.name,
      extension: file.extension ?? '',
      bytes: bytes,
    );
    try {
      selected.validate();
    } catch (_) {
      _message('Select a valid PDF or image, no larger than 20 MiB.');
      return;
    }
    final draft = await showDialog<_DocumentDraft>(
      context: context,
      builder: (_) =>
          _DocumentEditor(canManage: canManage, fileName: file.name),
    );
    if (!mounted || draft == null || !_sameScope(service, profileId)) return;
    try {
      await service.upload(
        profileId: profileId,
        file: selected,
        documentType: draft.type,
        title: draft.title,
        notes: draft.notes,
        visibility: canManage ? draft.visibility : null,
      );
      _refresh();
      _message('Document uploaded.');
    } on DocumentFinalizationException catch (e) {
      if (!mounted || !_sameScope(service, profileId)) return;
      setState(() {
        _pending = e;
        _pendingService = service;
      });
      _message('File uploaded. Retry finalization to complete the record.');
    }
  });

  bool _sameScope(DocumentsService service, String profileId) =>
      mounted &&
      widget.profileId == profileId &&
      ref.read(tenantIdProvider) == service.tenantId &&
      ref.read(appIdProvider) == service.appId &&
      identical(ref.read(documentsServiceProvider).asData?.value, service);

  Future<void> _retry() => _run((service) async {
    final pending = _pending;
    if (pending == null) return;
    if (!identical(service, _pendingService) ||
        !_sameScope(service, pending.profileId)) {
      setState(() {
        _pending = null;
        _pendingService = null;
      });
      _message(
        'Session changed. The previous upload must not be finalized here.',
      );
      return;
    }
    await service.create(profileId: pending.profileId, input: pending.input);
    if (!mounted) return;
    setState(() {
      _pending = null;
      _pendingService = null;
    });
    _refresh();
    _message('Document finalized.');
  });

  Future<void> _download(Document doc) => _run((service) async {
    final uri = await service.download(doc);
    if (!_sameScope(service, doc.profileId)) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _message('Unable to open document download.');
    }
  });

  Future<void> _edit(Document doc) => _run((service) async {
    if (!widget.canManage || !_sameScope(service, doc.profileId)) return;
    final draft = await showDialog<_DocumentDraft>(
      context: context,
      builder: (_) => _DocumentEditor(canManage: true, document: doc),
    );
    if (draft == null ||
        !_sameScope(service, doc.profileId) ||
        !widget.canManage)
      return;
    await service.update(
      doc,
      DocumentUpdateInput(
        documentType: draft.type,
        title: draft.title,
        clearTitle: draft.title == null,
        notes: draft.notes,
        clearNotes: draft.notes == null,
        visibility: draft.visibility,
        status: draft.status,
      ),
    );
    _refresh();
  });

  Future<void> _archive(Document doc) => _run((service) async {
    if (!widget.canManage || !_sameScope(service, doc.profileId)) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive document?'),
        content: const Text(
          'The document will be retained for audit but removed from active records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (yes != true || !_sameScope(service, doc.profileId) || !widget.canManage)
      return;
    await service.archive(doc);
    _refresh();
  });

  @override
  Widget build(BuildContext context) {
    if (widget.profileId.trim().isEmpty)
      return const Text('Profile ID is required.');
    final query = _query;
    final result = ref.watch(documentsControllerProvider(query));
    final service = ref.watch(documentsServiceProvider).asData?.value;
    final pending = _pending != null && identical(service, _pendingService);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
            if (widget.showUploadActions && _active)
              IconButton(
                tooltip: 'Upload document',
                onPressed: _busy || pending ? null : _upload,
                icon: const Icon(Icons.upload_file),
              ),
          ],
        ),
        if (widget.canManage)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show archived documents'),
            value: !_active,
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _active = !value;
                    _page = 1;
                  }),
          ),
        if (_busy) const LinearProgressIndicator(),
        if (pending)
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _busy ? null : _retry,
                child: const Text('Retry finalization'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _pending = null;
                        _pendingService = null;
                      }),
                child: const Text('Discard retry'),
              ),
            ],
          ),
        result.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Text('Unable to load documents. Refresh to retry.'),
          data: (docs) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (docs.isEmpty) Text(widget.emptyText),
              for (final doc in docs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    doc.contentType == 'application/pdf'
                        ? Icons.picture_as_pdf
                        : Icons.image_outlined,
                  ),
                  title: Text(doc.displayTitle),
                  subtitle: Text(
                    '${doc.documentType.label} · ${doc.status.label}\n${doc.fileName}',
                  ),
                  onTap: _busy ? null : () => _download(doc),
                  trailing: PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (action) {
                      switch (action) {
                        case 'download':
                          _download(doc);
                          break;
                        case 'edit':
                          _edit(doc);
                          break;
                        case 'archive':
                          _archive(doc);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'download',
                        child: Text('Download'),
                      ),
                      if (widget.canManage && doc.isActive)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit metadata'),
                        ),
                      if (widget.canManage && doc.isActive)
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('Archive'),
                        ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: _busy || _page == 1
                        ? null
                        : () => setState(() => _page--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Page $_page'),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed:
                        _busy || docs.length < documentsPageSize || _page >= 201
                        ? null
                        : () => setState(() => _page++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentDraft {
  const _DocumentDraft(
    this.type,
    this.title,
    this.notes,
    this.visibility,
    this.status,
  );
  final DocumentType type;
  final String? title, notes;
  final DocumentVisibility visibility;
  final DocumentStatus status;
}

class _DocumentEditor extends StatefulWidget {
  const _DocumentEditor({
    required this.canManage,
    this.document,
    this.fileName,
  });
  final bool canManage;
  final Document? document;
  final String? fileName;
  @override
  State<_DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<_DocumentEditor> {
  late DocumentType _type;
  late DocumentVisibility _visibility;
  late DocumentStatus _status;
  late TextEditingController _title, _notes;
  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    _type = doc?.documentType ?? DocumentType.other;
    _visibility =
        doc?.visibility ??
        (widget.canManage
            ? DocumentVisibility.staffOnly
            : DocumentVisibility.profileMember);
    _status = doc?.status ?? DocumentStatus.uploaded;
    _title = TextEditingController(text: doc?.title ?? '');
    _notes = TextEditingController(text: doc?.notes ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _optional(String text) => text.trim().isEmpty ? null : text.trim();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.document == null ? 'Upload document' : 'Edit document'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.fileName != null) Text(widget.fileName!),
            DropdownButtonFormField<DocumentType>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Document type'),
              items: DocumentType.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            TextField(
              controller: _title,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Title (optional)'),
            ),
            TextField(
              controller: _notes,
              maxLength: 4000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            if (widget.canManage)
              DropdownButtonFormField<DocumentVisibility>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: 'Visibility'),
                items: DocumentVisibility.values
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _visibility = v);
                },
              ),
            if (widget.document != null)
              DropdownButtonFormField<DocumentStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: DocumentStatus.values
                    .where((e) => e != DocumentStatus.archived)
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _DocumentDraft(
            _type,
            _optional(_title.text),
            _optional(_notes.text),
            _visibility,
            _status,
          ),
        ),
        child: Text(widget.document == null ? 'Upload' : 'Save'),
      ),
    ],
  );
}
