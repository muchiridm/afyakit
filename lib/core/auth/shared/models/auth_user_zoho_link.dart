// lib/core/auth/shared/models/auth_user_zoho_link.dart

import 'package:flutter/foundation.dart';

/// How the Zoho link was established (backend-aligned).
enum ZohoMatchStrategy {
  phone,
  email,
  manual,
  created;

  String get wire => name;

  static ZohoMatchStrategy parse(dynamic raw) {
    final s = (raw ?? '').toString().trim().toLowerCase();
    switch (s) {
      case 'phone':
        return ZohoMatchStrategy.phone;
      case 'email':
        return ZohoMatchStrategy.email;
      case 'created':
        return ZohoMatchStrategy.created;
      case 'manual':
      default:
        return ZohoMatchStrategy.manual;
    }
  }
}

@immutable
class AuthUserZohoLink {
  final String contactId;
  final String? contactPersonId;

  /// ISO timestamp string (backend uses serverTimestamp; API returns ISO).
  final String? linkedAt;

  /// How the link was established.
  /// Backend guarantees a value (defaults to "manual").
  final ZohoMatchStrategy matchStrategy;

  /// Optional sync metadata
  final String? syncedAt;
  final List<String>? lastSyncReasons;

  const AuthUserZohoLink({
    required this.contactId,
    this.contactPersonId,
    this.linkedAt,
    this.matchStrategy = ZohoMatchStrategy.manual,
    this.syncedAt,
    this.lastSyncReasons,
  });

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  static String _cleanStr(dynamic v) => (v ?? '').toString().trim();

  static String? _optStr(dynamic v) {
    final s = _cleanStr(v);
    return s.isEmpty ? null : s;
  }

  static List<String>? _optStringList(dynamic v) {
    if (v is! List) return null;
    final out = <String>[];
    for (final x in v) {
      final s = _cleanStr(x);
      if (s.isNotEmpty) out.add(s);
    }
    if (out.isEmpty) return null;

    final seen = <String>{};
    return out.where(seen.add).toList(growable: false);
  }

  // ─────────────────────────────────────────────
  // Parsing
  // ─────────────────────────────────────────────

  factory AuthUserZohoLink.fromMap(Map<String, dynamic> json) {
    final contactId = _cleanStr(json['contactId']);
    if (contactId.isEmpty) {
      throw ArgumentError('AuthUserZohoLink requires contactId');
    }

    return AuthUserZohoLink(
      contactId: contactId,
      contactPersonId: _optStr(json['contactPersonId']),
      linkedAt: _optStr(json['linkedAt']),
      matchStrategy: ZohoMatchStrategy.parse(json['matchStrategy']),
      syncedAt: _optStr(json['syncedAt']),
      lastSyncReasons: _optStringList(json['lastSyncReasons']),
    );
  }

  Map<String, dynamic> toMap() => {
    'contactId': contactId,
    'matchStrategy': matchStrategy.wire,
    if (contactPersonId != null) 'contactPersonId': contactPersonId,
    if (linkedAt != null) 'linkedAt': linkedAt,
    if (syncedAt != null) 'syncedAt': syncedAt,
    if (lastSyncReasons != null && lastSyncReasons!.isNotEmpty)
      'lastSyncReasons': lastSyncReasons,
  };
}
