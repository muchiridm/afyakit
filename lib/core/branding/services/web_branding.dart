// lib/core/branding/services/web_branding.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

import 'package:afyakit/app/models/app_profile.dart';

/// Applies the active app's branding to the browser DOM.
///
/// AppProfile is the source of truth for:
/// - document title
/// - description
/// - theme colour
/// - favicon
/// - PWA/browser icons
void applyAppBrandingToDom(AppProfile profile) {
  if (!kIsWeb) return;

  final document = html.document;

  document.title = profile.webTitle;

  _setDescription(document, profile.webDescription);

  _setThemeColor(document, profile.primaryColorHex);

  _setFavicon(document, profile.assets.faviconUrl);

  _setIcon192(document, profile.assets.icon192Url);

  _setIcon512(document, profile.assets.icon512Url);
}

html.Element? _head(html.Document document) {
  return document.querySelector('head');
}

void _appendToHead(html.Document document, html.Element element) {
  _head(document)?.append(element);
}

void _setDescription(html.Document document, String description) {
  final value = description.trim();

  if (value.isEmpty) return;

  final existing =
      document.querySelector('meta[name="description"]') as html.MetaElement?;

  if (existing != null) {
    existing.content = value;
    return;
  }

  final meta = html.MetaElement()
    ..name = 'description'
    ..content = value;

  _appendToHead(document, meta);
}

void _setThemeColor(html.Document document, String color) {
  final existing =
      document.querySelector('meta[name="theme-color"]') as html.MetaElement?;

  if (existing != null) {
    existing.content = color;
    return;
  }

  final meta = html.MetaElement()
    ..name = 'theme-color'
    ..content = color;

  _appendToHead(document, meta);
}

void _setFavicon(html.Document document, String? url) {
  final value = url?.trim();

  if (value == null || value.isEmpty) {
    return;
  }

  final icon =
      document.querySelector('#app-favicon') as html.LinkElement? ??
      (html.LinkElement()
        ..id = 'app-favicon'
        ..rel = 'icon'
        ..type = 'image/png');

  icon.href = value;

  if (icon.parent == null) {
    _appendToHead(document, icon);
  }

  final shortcut =
      document.querySelector('#app-favicon-shortcut') as html.LinkElement? ??
      (html.LinkElement()
        ..id = 'app-favicon-shortcut'
        ..rel = 'shortcut icon'
        ..type = 'image/png');

  shortcut.href = value;

  if (shortcut.parent == null) {
    _appendToHead(document, shortcut);
  }
}

void _setIcon192(html.Document document, String? url) {
  final value = url?.trim();

  if (value == null || value.isEmpty) {
    return;
  }

  final apple =
      document.querySelector('#apple-touch-icon') as html.LinkElement? ??
      (html.LinkElement()
        ..id = 'apple-touch-icon'
        ..rel = 'apple-touch-icon');

  apple.href = value;
  apple.setAttribute('sizes', '192x192');

  if (apple.parent == null) {
    _appendToHead(document, apple);
  }

  final icon =
      document.querySelector('#app-icon-192') as html.LinkElement? ??
      (html.LinkElement()
        ..id = 'app-icon-192'
        ..rel = 'icon'
        ..type = 'image/png');

  icon.href = value;
  icon.setAttribute('sizes', '192x192');

  if (icon.parent == null) {
    _appendToHead(document, icon);
  }
}

void _setIcon512(html.Document document, String? url) {
  final value = url?.trim();

  if (value == null || value.isEmpty) {
    return;
  }

  final icon =
      document.querySelector('#app-icon-512') as html.LinkElement? ??
      (html.LinkElement()
        ..id = 'app-icon-512'
        ..rel = 'icon'
        ..type = 'image/png');

  icon.href = value;
  icon.setAttribute('sizes', '512x512');

  if (icon.parent == null) {
    _appendToHead(document, icon);
  }
}
