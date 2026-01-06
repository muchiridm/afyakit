import 'dart:typed_data';

import 'package:afyakit/features/hq/branding/controllers/tenant_branding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/core/branding/services/tenant_storage.dart';

class TenantBrandingScreen extends ConsumerWidget {
  const TenantBrandingScreen({super.key, required this.initial});

  /// The tenant we’re editing (e.g. "dawapap", "rpmoc").
  final TenantProfile initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tenantBrandingControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Branding & Web · ${initial.displayName}')),
      body: AbsorbPointer(
        absorbing: state.savingProfile || state.uploadingAsset,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _IdentitySection(profile: initial),
            const SizedBox(height: 24),
            _SeoSection(profile: initial),
            const SizedBox(height: 24),
            _AssetsSection(profile: initial),
            const SizedBox(height: 24),
            if (state.error != null)
              Text(state.error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class _IdentitySection extends ConsumerStatefulWidget {
  const _IdentitySection({required this.profile});

  final TenantProfile profile;

  @override
  ConsumerState<_IdentitySection> createState() => _IdentitySectionState();
}

class _IdentitySectionState extends ConsumerState<_IdentitySection> {
  late TextEditingController _tagline;
  late TextEditingController _primaryColor;

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
    final ctrl = ref.read(tenantBrandingControllerProvider.notifier);
    final state = ref.watch(tenantBrandingControllerProvider);

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
                labelText: 'Primary color hex',
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
                    : () => ctrl.saveProfileBranding(
                        slug: widget.profile.id,
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
  const _SeoSection({required this.profile});

  final TenantProfile profile;

  @override
  ConsumerState<_SeoSection> createState() => _SeoSectionState();
}

class _SeoSectionState extends ConsumerState<_SeoSection> {
  late TextEditingController _title;
  late TextEditingController _description;

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
    final ctrl = ref.read(tenantBrandingControllerProvider.notifier);
    final state = ref.watch(tenantBrandingControllerProvider);

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
                    : () => ctrl.saveProfileBranding(
                        slug: widget.profile.id,
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
  const _AssetsSection({required this.profile});

  final TenantProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(tenantBrandingControllerProvider.notifier);
    final state = ref.watch(tenantBrandingControllerProvider);

    Future<void> handleUpload(TenantWebAssetType type) async {
      final bytes = await _pickImageBytes(); // TODO: implement per-platform
      if (bytes == null) return;
      await ctrl.uploadWebAsset(slug: profile.id, type: type, bytes: bytes);
    }

    Future<void> handleDelete(TenantWebAssetType type) async {
      await ctrl.deleteWebAsset(slug: profile.id, type: type);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Web assets', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _assetRow(
              context: context,
              label: 'Favicon',
              url: _webAssetPreviewUrl(profile, TenantWebAssetType.favicon),
              onUpload: () => handleUpload(TenantWebAssetType.favicon),
              onDelete: () => handleDelete(TenantWebAssetType.favicon),
              busy: state.uploadingAsset,
            ),
            const SizedBox(height: 12),
            _assetRow(
              context: context,
              label: 'Icon 192×192',
              url: _webAssetPreviewUrl(profile, TenantWebAssetType.icon192),
              onUpload: () => handleUpload(TenantWebAssetType.icon192),
              onDelete: () => handleDelete(TenantWebAssetType.icon192),
              busy: state.uploadingAsset,
            ),
            const SizedBox(height: 12),
            _assetRow(
              context: context,
              label: 'Icon 512×512',
              url: _webAssetPreviewUrl(profile, TenantWebAssetType.icon512),
              onUpload: () => handleUpload(TenantWebAssetType.icon512),
              onDelete: () => handleDelete(TenantWebAssetType.icon512),
              busy: state.uploadingAsset,
            ),
          ],
        ),
      ),
    );
  }

  Widget _assetRow({
    required BuildContext context,
    required String label,
    required String url,
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
            child: Image.network(
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
          onPressed: busy ? null : onDelete,
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

// Helpers for preview URL and picking bytes

String _webAssetPreviewUrl(TenantProfile profile, TenantWebAssetType type) {
  final bucket = profile.assets.bucket.isNotEmpty
      ? profile.assets.bucket
      : 'afyakit-api.firebasestorage.app';

  final fileName = switch (type) {
    TenantWebAssetType.favicon => 'favicon.png',
    TenantWebAssetType.icon192 => 'icon-192.png',
    TenantWebAssetType.icon512 => 'icon-512.png',
  };

  final base =
      'https://storage.googleapis.com/$bucket/public/${profile.id}/web/$fileName';

  return profile.assets.version > 0
      ? '$base?v=${profile.assets.version}'
      : base;
}

Future<Uint8List?> _pickImageBytes() async {
  // Stub: implement with file_picker / image_picker / html <input> depending
  // on your target platforms. Returning null means "user cancelled".
  return null;
}
