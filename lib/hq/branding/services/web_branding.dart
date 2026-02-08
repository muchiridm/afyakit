// lib/hq/tenants/services/web_branding.dart
import 'package:afyakit/hq/tenants/models/tenant_assets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

import 'package:afyakit/hq/tenants/models/tenant_profile.dart';

/// Apply per-tenant branding to the browser DOM on web.
///
/// Uses:
///   - profile.webTitle        → <title>
///   - profile.webDescription  → <meta name="description">
///   - profile.primaryColorHex → <meta name="theme-color">
///   - profile.assets.*Url     → favicon + icons
///
/// IMPORTANT:
/// We intentionally DO NOT construct storage.googleapis.com URLs here.
/// Those will CORS/403 unless your bucket is public + has CORS configured.
/// Instead, we rely on TenantAssets returning web-safe URLs
/// (Firebase Storage download URLs).
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
  final desc = profile.webDescription.trim();
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
  final themeHex = profile.primaryColorHex.trim();
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
  // Favicon (rel=icon + shortcut icon)
  // ─────────────────────────────────────────────
  final faviconUrl = profile.assets.faviconUrl?.trim();
  if (faviconUrl != null && faviconUrl.isNotEmpty) {
    // rel="icon"
    final icon =
        doc.querySelector('#app-favicon') as html.LinkElement? ??
        (html.LinkElement()
          ..id = 'app-favicon'
          ..rel = 'icon'
          ..type = 'image/png');
    icon.href = faviconUrl;
    if (icon.parent == null) doc.head?.append(icon);

    // rel="shortcut icon" (legacy but still helps)
    final shortcut =
        doc.querySelector('#app-favicon-shortcut') as html.LinkElement? ??
        (html.LinkElement()
          ..id = 'app-favicon-shortcut'
          ..rel = 'shortcut icon'
          ..type = 'image/png');
    shortcut.href = faviconUrl;
    if (shortcut.parent == null) doc.head?.append(shortcut);
  }

  // ─────────────────────────────────────────────
  // Apple touch icon (192x192)
  // ─────────────────────────────────────────────
  final icon192Url = profile.assets.icon192Url?.trim();
  if (icon192Url != null && icon192Url.isNotEmpty) {
    final apple =
        doc.querySelector('#apple-touch-icon') as html.LinkElement? ??
        (html.LinkElement()
          ..id = 'apple-touch-icon'
          ..rel = 'apple-touch-icon');

    apple.href = icon192Url;
    apple.setAttribute('sizes', '192x192');
    if (apple.parent == null) doc.head?.append(apple);

    // Also register as a normal icon for Chrome in some cases
    final icon192 =
        doc.querySelector('#app-icon-192') as html.LinkElement? ??
        (html.LinkElement()
          ..id = 'app-icon-192'
          ..rel = 'icon'
          ..type = 'image/png');
    icon192.href = icon192Url;
    icon192.setAttribute('sizes', '192x192');
    if (icon192.parent == null) doc.head?.append(icon192);
  }

  // ─────────────────────────────────────────────
  // Optional: icon 512 (helps install prompts / PWA visuals)
  // ─────────────────────────────────────────────
  final icon512Url = profile.assets.icon512Url?.trim();
  if (icon512Url != null && icon512Url.isNotEmpty) {
    final icon512 =
        doc.querySelector('#app-icon-512') as html.LinkElement? ??
        (html.LinkElement()
          ..id = 'app-icon-512'
          ..rel = 'icon'
          ..type = 'image/png');
    icon512.href = icon512Url;
    icon512.setAttribute('sizes', '512x512');
    if (icon512.parent == null) doc.head?.append(icon512);
  }
}
