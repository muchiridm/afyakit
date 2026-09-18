// lib/features/hq/apps/widgets/app_branding_screen.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/core/branding/services/branding_storage.dart';
import 'package:afyakit/features/hq/apps/controllers/app_branding_controller.dart';

class AppBrandingScreen extends ConsumerWidget {
  const AppBrandingScreen({
    super.key,
    required this.tenantId,
    required this.initial,
  });

  final String tenantId;
  final AppProfile initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appBrandingControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Branding & Web · ${initial.displayName}')),
      body: AbsorbPointer(
        absorbing: state.busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _IdentitySection(tenantId: tenantId, profile: initial),
            const SizedBox(height: 24),
            _SeoSection(tenantId: tenantId, profile: initial),
            const SizedBox(height: 24),
            _AssetsSection(tenantId: tenantId, profile: initial),
            if (state.error != null) ...[
              const SizedBox(height: 24),
              Text(state.error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

class _IdentitySection extends ConsumerStatefulWidget {
  const _IdentitySection({required this.tenantId, required this.profile});

  final String tenantId;
  final AppProfile profile;

  @override
  ConsumerState<_IdentitySection> createState() => _IdentitySectionState();
}

class _IdentitySectionState extends ConsumerState<_IdentitySection> {
  late final TextEditingController _tagline;
  late final TextEditingController _primaryColor;

  @override
  void initState() {
    super.initState();

    _tagline = TextEditingController(
      text: widget.profile.details.tagline ?? '',
    );

    _primaryColor = TextEditingController(text: widget.profile.primaryColorHex);
  }

  @override
  void dispose() {
    _tagline.dispose();
    _primaryColor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(appBrandingControllerProvider.notifier);

    final state = ref.watch(appBrandingControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Identity', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagline,
              decoration: const InputDecoration(
                labelText: 'Tagline',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _primaryColor,
              decoration: const InputDecoration(
                labelText: 'Primary colour hex',
                hintText: '#2196F3',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: state.savingProfile
                    ? null
                    : () => controller.saveProfileBranding(
                        tenantId: widget.tenantId,
                        appId: widget.profile.id,
                        seoTitle:
                            widget.profile.details.seoTitle ??
                            widget.profile.displayName,
                        seoDescription:
                            widget.profile.details.seoDescription ?? '',
                        tagline: _tagline.text.trim(),
                        primaryColorHex: _primaryColor.text.trim(),
                      ),
                icon: state.savingProfile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save identity'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeoSection extends ConsumerStatefulWidget {
  const _SeoSection({required this.tenantId, required this.profile});

  final String tenantId;
  final AppProfile profile;

  @override
  ConsumerState<_SeoSection> createState() => _SeoSectionState();
}

class _SeoSectionState extends ConsumerState<_SeoSection> {
  late final TextEditingController _title;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();

    _title = TextEditingController(text: widget.profile.details.seoTitle ?? '');

    _description = TextEditingController(
      text: widget.profile.details.seoDescription ?? '',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(appBrandingControllerProvider.notifier);

    final state = ref.watch(appBrandingControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SEO', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Browser tab title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Meta description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: state.savingProfile
                    ? null
                    : () => controller.saveProfileBranding(
                        tenantId: widget.tenantId,
                        appId: widget.profile.id,
                        seoTitle: _title.text.trim(),
                        seoDescription: _description.text.trim(),
                        tagline: widget.profile.details.tagline ?? '',
                        primaryColorHex: widget.profile.primaryColorHex,
                      ),
                icon: state.savingProfile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save SEO'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetsSection extends ConsumerWidget {
  const _AssetsSection({required this.tenantId, required this.profile});

  final String tenantId;
  final AppProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appBrandingControllerProvider.notifier);

    final state = ref.watch(appBrandingControllerProvider);

    Future<void> handleUpload(BrandingWebAssetType type) async {
      final bytes = await _pickImageBytes();

      if (bytes == null) return;

      await controller.uploadWebAsset(
        tenantId: tenantId,
        appId: profile.id,
        type: type,
        bytes: bytes,
      );
    }

    Future<void> handleDelete(BrandingWebAssetType type) async {
      await controller.deleteWebAsset(
        tenantId: tenantId,
        appId: profile.id,
        type: type,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Web assets', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            for (final type in BrandingWebAssetType.values) ...[
              _assetRow(
                context: context,
                label: _assetLabel(type),
                url: profile.assets.logoUrl(prefer: type.key),
                onUpload: () => handleUpload(type),
                onDelete: () => handleDelete(type),
                busy: state.uploadingAsset,
              ),
              if (type != BrandingWebAssetType.values.last)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assetRow({
    required BuildContext context,
    required String label,
    required String? url,
    required VoidCallback onUpload,
    required VoidCallback onDelete,
    required bool busy,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: url == null
                ? Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, size: 18),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey.shade200),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        TextButton(
          onPressed: busy || url == null ? null : onDelete,
          child: const Text('Remove'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: busy ? null : onUpload,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload),
          label: const Text('Upload'),
        ),
      ],
    );
  }
}

String _assetLabel(BrandingWebAssetType type) {
  return switch (type) {
    BrandingWebAssetType.favicon => 'Favicon',
    BrandingWebAssetType.icon192 => 'Icon 192×192',
    BrandingWebAssetType.icon512 => 'Icon 512×512',
    BrandingWebAssetType.maskableIcon192 => 'Maskable icon 192×192',
    BrandingWebAssetType.maskableIcon512 => 'Maskable icon 512×512',
  };
}

Future<Uint8List?> _pickImageBytes() async {
  // Existing picker integration can be wired here.
  // null means the user cancelled.
  return null;
}
