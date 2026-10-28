import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/core/branding/services/branding_storage.dart';
import 'package:afyakit/features/hq/apps/controllers/app_branding_controller.dart';
import 'package:afyakit/features/hq/apps/providers/hq_app_profiles_provider.dart';

class AppBrandingScreen extends ConsumerStatefulWidget {
  const AppBrandingScreen({
    super.key,
    required this.tenantId,
    required this.initial,
  });

  final String tenantId;
  final AppProfile initial;

  @override
  ConsumerState<AppBrandingScreen> createState() => _AppBrandingScreenState();
}

class _AppBrandingScreenState extends ConsumerState<AppBrandingScreen> {
  late final TextEditingController _color;

  // Cache Futures, not URLs. An explicit refresh or
  // successful asset change clears the relevant Future.
  final Map<String, Future<String?>> _assetUrls = {};

  int _imageVersion = 0;

  BrandingStorageService get _storage =>
      ref.read(brandingStorageServiceProvider);

  @override
  void initState() {
    super.initState();
    _color = TextEditingController(text: widget.initial.primaryColorHex);
  }

  @override
  void dispose() {
    _color.dispose();
    super.dispose();
  }

  AppProfile _currentProfile() {
    final apps = ref.watch(hqAppProfilesProvider(widget.tenantId)).valueOrNull;

    if (apps != null) {
      for (final app in apps) {
        if (app.id == widget.initial.id) return app;
      }
    }

    return widget.initial;
  }

  Future<String?> _logoUrl(BrandingLogoType type) {
    final key = 'logo:${type.key}';

    return _assetUrls.putIfAbsent(
      key,
      () => _storage.getLogoDownloadUrl(
        tenantId: widget.tenantId,
        appId: widget.initial.id,
        type: type,
      ),
    );
  }

  Future<String?> _webUrl(BrandingWebAssetType type) {
    final key = 'web:${type.key}';

    return _assetUrls.putIfAbsent(
      key,
      () => _storage.getWebAssetDownloadUrl(
        tenantId: widget.tenantId,
        appId: widget.initial.id,
        type: type,
      ),
    );
  }

  void _refreshAssets([String? key]) {
    if (!mounted) return;

    setState(() {
      if (key == null) {
        _assetUrls.clear();
      } else {
        _assetUrls.remove(key);
      }

      // Forces a fresh image request when an object
      // was replaced at the same Storage path.
      _imageVersion++;
    });
  }

  Future<void> _saveColor() async {
    final ok = await ref
        .read(appBrandingControllerProvider.notifier)
        .saveColor(
          tenantId: widget.tenantId,
          appId: widget.initial.id,
          primaryColorHex: _color.text,
        );

    if (!mounted || !ok) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Accent colour saved.')));
  }

  Future<Uint8List?> _pickPng() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
      withData: true,
    );

    if (result == null) return null;

    final bytes = result.files.single.bytes;

    if (bytes == null || bytes.isEmpty) {
      throw StateError('The selected file could not be read.');
    }

    return bytes;
  }

  Future<void> _uploadLogo(BrandingLogoType type) async {
    try {
      final bytes = await _pickPng();
      if (bytes == null) return;

      final ok = await ref
          .read(appBrandingControllerProvider.notifier)
          .uploadLogo(
            tenantId: widget.tenantId,
            appId: widget.initial.id,
            type: type,
            bytes: bytes,
          );

      if (ok) _refreshAssets('logo:${type.key}');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _uploadWebAsset(BrandingWebAssetType type) async {
    try {
      final bytes = await _pickPng();
      if (bytes == null) return;

      final ok = await ref
          .read(appBrandingControllerProvider.notifier)
          .uploadWebAsset(
            tenantId: widget.tenantId,
            appId: widget.initial.id,
            type: type,
            bytes: bytes,
          );

      if (ok) _refreshAssets('web:${type.key}');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteLogo(BrandingLogoType type) async {
    if (!await _confirmRemove()) return;

    if (!mounted) return;

    final ok = await ref
        .read(appBrandingControllerProvider.notifier)
        .deleteLogo(
          tenantId: widget.tenantId,
          appId: widget.initial.id,
          type: type,
        );

    if (ok) _refreshAssets('logo:${type.key}');
  }

  Future<void> _deleteWebAsset(BrandingWebAssetType type) async {
    if (!await _confirmRemove()) return;

    if (!mounted) return;

    final ok = await ref
        .read(appBrandingControllerProvider.notifier)
        .deleteWebAsset(
          tenantId: widget.tenantId,
          appId: widget.initial.id,
          type: type,
        );

    if (ok) _refreshAssets('web:${type.key}');
  }

  Future<bool> _confirmRemove() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Remove image?'),
            content: const Text(
              'This deletes the image from Firebase '
              'Storage and removes its profile reference.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(Object error) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$error')));
  }

  void _showPreview(String label, String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 650),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Image.network(
                      _versionedUrl(url),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Text('Could not display this image.'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _versionedUrl(String url) {
    final uri = Uri.parse(url);

    return uri
        .replace(
          queryParameters: {...uri.queryParameters, 'v': '$_imageVersion'},
        )
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appBrandingControllerProvider);
    final profile = _currentProfile();

    final enteredColor = _color.text.trim();

    final validColor = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(enteredColor);

    final previewColor = validColor
        ? Color(int.parse('FF${enteredColor.substring(1)}', radix: 16))
        : profile.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('Branding · ${profile.displayName}'),
        actions: [
          IconButton(
            tooltip: 'Refresh image previews',
            onPressed: state.busy ? null : () => _refreshAssets(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: state.busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Tenant: ${widget.tenantId}'
              '  ·  App: ${profile.id}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            _Section(
              title: 'Accent colour',
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: previewColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _color,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Primary colour hex',
                            hintText: '#2196F3',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: state.busy ? null : _saveColor,
                      icon: const Icon(Icons.save),
                      label: Text(
                        state.savingColor ? 'Saving…' : 'Save colour',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _Section(
              title: 'Logos',
              child: Column(
                children: [
                  for (final type in BrandingLogoType.values)
                    _AssetRow(
                      key: ValueKey('logo:${type.key}:$_imageVersion'),
                      label: type == BrandingLogoType.primary
                          ? 'Primary · header'
                          : 'Secondary · splash',
                      urlFuture: _logoUrl(type),
                      busy: state.busy,
                      versionedUrl: _versionedUrl,
                      onPreview: _showPreview,
                      onUpload: () => _uploadLogo(type),
                      onRemove: () => _deleteLogo(type),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _Section(
              title: 'Browser & PWA icons',
              child: Column(
                children: [
                  for (final type in BrandingWebAssetType.values)
                    _AssetRow(
                      key: ValueKey('web:${type.key}:$_imageVersion'),
                      label: switch (type) {
                        BrandingWebAssetType.favicon => 'Favicon',
                        BrandingWebAssetType.icon192 => 'Icon 192×192',
                        BrandingWebAssetType.icon512 => 'Icon 512×512',
                        BrandingWebAssetType.maskableIcon192 =>
                          'Maskable 192×192',
                        BrandingWebAssetType.maskableIcon512 =>
                          'Maskable 512×512',
                      },
                      urlFuture: _webUrl(type),
                      busy: state.busy,
                      versionedUrl: _versionedUrl,
                      onPreview: _showPreview,
                      onUpload: () => _uploadWebAsset(type),
                      onRemove: () => _deleteWebAsset(type),
                    ),
                ],
              ),
            ),

            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    super.key,
    required this.label,
    required this.urlFuture,
    required this.busy,
    required this.versionedUrl,
    required this.onPreview,
    required this.onUpload,
    required this.onRemove,
  });

  final String label;
  final Future<String?> urlFuture;
  final bool busy;

  final String Function(String) versionedUrl;
  final void Function(String, String) onPreview;

  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: urlFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;

        final error = snapshot.error;

        final url = snapshot.data;
        final hasImage = url != null && url.trim().isNotEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : error != null
                    ? const Icon(Icons.error_outline)
                    : !hasImage
                    ? const Icon(Icons.image_not_supported_outlined)
                    : Image.network(
                        versionedUrl(url),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
              ),

              SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label),
                    if (error != null)
                      Text(
                        'Could not load image',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),

              if (hasImage)
                TextButton.icon(
                  onPressed: busy ? null : () => onPreview(label, url),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Preview'),
                ),

              FilledButton.tonalIcon(
                onPressed: busy || loading ? null : onUpload,
                icon: const Icon(Icons.upload_file),
                label: Text(hasImage ? 'Replace' : 'Upload'),
              ),

              TextButton.icon(
                onPressed: busy || !hasImage ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
            ],
          ),
        );
      },
    );
  }
}
