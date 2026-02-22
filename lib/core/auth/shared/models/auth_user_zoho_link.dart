// lib/core/auth/shared/models/auth_user_zoho_link.dart

import 'package:flutter/foundation.dart';

enum ZohoMatchStrategy {
  accountNumber,
  phone,
  email,
  manual,
  created;

  String get wire {
    switch (this) {
      case ZohoMatchStrategy.accountNumber:
        return 'account_number';
      default:
        return name;
    }
  }

  static ZohoMatchStrategy parse(dynamic raw) {
    final s = (raw ?? '').toString().trim().toLowerCase();
    switch (s) {
      case 'account_number':
      case 'accountnumber':
        return ZohoMatchStrategy.accountNumber;
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

  /// ISO timestamp string (backend returns ISO).
  final String? linkedAt;

  final ZohoMatchStrategy matchStrategy;

  final String? syncedAt;

  /// Sync reasons from backend
  final List<String>? lastSyncReasons;

  /// Bootstrap reasons (linking phase)
  final List<String>? lastBootstrapReasons;

  // ─────────────────────────────
  // Deterministic linking (new policy)
  // ─────────────────────────────
  final String? accountNumber;

  // ─────────────────────────────
  // Observability snapshot fields (persistZohoSnapshot)
  // ─────────────────────────────
  final String? contactType; // can be null in BE; keep nullable string here
  final String? status; // can be null in BE; keep nullable string here

  const AuthUserZohoLink({
    required this.contactId,
    this.contactPersonId,
    this.linkedAt,
    this.matchStrategy = ZohoMatchStrategy.manual,
    this.syncedAt,
    this.lastSyncReasons,
    this.lastBootstrapReasons,
    this.accountNumber,
    this.contactType,
    this.status,
  });

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

  factory AuthUserZohoLink.fromMap(Map<String, dynamic> json) {
    final contactId = _cleanStr(json['contactId']);
    if (contactId.isEmpty) {
      throw ArgumentError('AuthUserZohoLink requires contactId');
    }

    final accountNumber =
        _optStr(json['accountNumber']) ?? _optStr(json['account_number']);

    return AuthUserZohoLink(
      contactId: contactId,
      contactPersonId: _optStr(json['contactPersonId']),
      linkedAt: _optStr(json['linkedAt']),
      matchStrategy: ZohoMatchStrategy.parse(json['matchStrategy']),
      syncedAt: _optStr(json['syncedAt']),
      lastSyncReasons: _optStringList(json['lastSyncReasons']),
      lastBootstrapReasons: _optStringList(json['lastBootstrapReasons']),
      accountNumber: accountNumber,
      contactType: json['contactType'] == null
          ? null
          : _optStr(json['contactType']),
      status: json['status'] == null ? null : _optStr(json['status']),
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
    if (lastBootstrapReasons != null && lastBootstrapReasons!.isNotEmpty)
      'lastBootstrapReasons': lastBootstrapReasons,
    if (accountNumber != null) 'accountNumber': accountNumber,
    if (contactType != null) 'contactType': contactType,
    if (status != null) 'status': status,
  };
}
