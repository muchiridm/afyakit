// lib/hq/tenants/services/web_branding.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

import 'package:afyakit/hq/tenants/models/tenant_profile.dart';

/// Apply per-tenant branding to the browser DOM on web.
///
/// Uses:
///   - profile.webTitle        → <title>
///   - profile.webDescription  → <meta name="description">
///   - profile.primaryColorHex → <meta name="theme-color">
///   - Storage convention      → favicon + 192x192 icon:
///       public/{tenantSlug}/web/favicon.png
///       public/{tenantSlug}/web/icon-192.png
void applyTenantBrandingToDom(TenantProfile profile) {
  if (!kIsWeb) return;

  final doc = html.document;

  // ─────────────────────────────────────────────
  // Title
  // ─────────────────────────────────────────────
  doc.title = profile.webTitle;

  // ─────────────────────────────────────────────
  // Description
  // ─────────────────────────────────────────────
  final desc = profile.webDescription;
  if (desc.isNotEmpty) {
    final existing =
        doc.querySelector('meta[name="description"]') as html.MetaElement?;
    if (existing != null) {
      existing.content = desc;
    } else {
      final m = html.MetaElement()
        ..name = 'description'
        ..content = desc;
      doc.head?.append(m);
    }
  }

  // ─────────────────────────────────────────────
  // Theme color
  // ─────────────────────────────────────────────
  final themeHex = profile.primaryColorHex;
  final themeMeta =
      doc.querySelector('meta[name="theme-color"]') as html.MetaElement?;
  if (themeMeta != null) {
    themeMeta.content = themeHex;
  } else {
    final m = html.MetaElement()
      ..name = 'theme-color'
      ..content = themeHex;
    doc.head?.append(m);
  }

  // ─────────────────────────────────────────────
  // Favicon (convention: public/{slug}/web/favicon.png)
  // ─────────────────────────────────────────────
  final faviconUrl = _webAssetUrl(profile, 'favicon.png');
  final favLink =
      doc.querySelector('#app-favicon') as html.LinkElement? ??
      (html.LinkElement()
        ..id = 'app-favicon'
        ..rel = 'icon'
        ..type = 'image/png');

  favLink.href = faviconUrl;
  if (favLink.parent == null) {
    doc.head?.append(favLink);
  }

  // ─────────────────────────────────────────────
  // Apple / PWA icon 192×192
  // (convention: public/{slug}/web/icon-192.png)
  // ─────────────────────────────────────────────
  final icon192Url = _webAssetUrl(profile, 'icon-192.png');
  final apple =
      doc.querySelector('#apple-touch-icon') as html.LinkElement? ??
      (html.LinkElement()
        ..id = 'apple-touch-icon'
        ..rel = 'apple-touch-icon');

  apple.href = icon192Url;
  if (apple.parent == null) {
    doc.head?.append(apple);
  }

  // If you later add a per-tenant manifest endpoint, you can point the
  // #app-manifest link there from here.
}

/// Build a public HTTPS URL for a web asset following:
///   public/{tenantSlug}/web/{fileName}
/// against the tenant bucket + version.
String _webAssetUrl(TenantProfile profile, String fileName) {
  final bucket = profile.assets.bucket.isNotEmpty
      ? profile.assets.bucket
      : 'afyakit-api.firebasestorage.app';

  final base =
      'https://storage.googleapis.com/$bucket/public/${profile.id}/web/$fileName';

  if (profile.assets.version > 0) {
    return '$base?v=${profile.assets.version}';
  }
  return base;
}
