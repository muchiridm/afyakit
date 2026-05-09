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
  const AuthUserZohoLink({
    required this.contactId,
    this.contactPersonId,
    this.linkedAt,
    this.matchStrategy = ZohoMatchStrategy.manual,
    this.syncedAt,
    this.lastSyncReasons,
    this.lastBootstrapReasons,
    this.accountNumber,
    this.previousAccountNumbers = const <String>[],
    this.contactType,
    this.status,
  });

  final String contactId;
  final String? contactPersonId;

  /// ISO timestamp string.
  final String? linkedAt;

  final ZohoMatchStrategy matchStrategy;

  final String? syncedAt;

  /// Sync reasons from backend.
  final List<String>? lastSyncReasons;

  /// Bootstrap reasons from backend.
  final List<String>? lastBootstrapReasons;

  /// Current deterministic Zoho/account linking key.
  ///
  /// New format:
  ///   AC-XXXXXX
  ///
  /// Legacy numeric values may still exist during recovery.
  final String? accountNumber;

  /// Previous account numbers linked to the same Zoho contact.
  ///
  /// Used for recovery/history lookup compatibility.
  final List<String> previousAccountNumbers;

  /// Observability snapshot fields from BE persistZohoSnapshot.
  final String? contactType;
  final String? status;

  bool get hasPreviousAccountNumbers => previousAccountNumbers.isNotEmpty;

  static String _cleanStr(dynamic v) => (v ?? '').toString().trim();

  static String? _optStr(dynamic v) {
    final s = _cleanStr(v);
    return s.isEmpty ? null : s;
  }

  static String? _optUpperStr(dynamic v) {
    final s = _cleanStr(v).toUpperCase();
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

  static List<String> _stringList(dynamic v) {
    return _optStringList(v) ?? const <String>[];
  }

  factory AuthUserZohoLink.fromMap(Map<String, dynamic> json) {
    final contactId = _cleanStr(json['contactId']);

    if (contactId.isEmpty) {
      throw ArgumentError('AuthUserZohoLink requires contactId');
    }

    final accountNumber =
        _optUpperStr(json['accountNumber']) ??
        _optUpperStr(json['account_number']);

    return AuthUserZohoLink(
      contactId: contactId,
      contactPersonId: _optStr(json['contactPersonId']),
      linkedAt: _optStr(json['linkedAt']),
      matchStrategy: ZohoMatchStrategy.parse(json['matchStrategy']),
      syncedAt: _optStr(json['syncedAt']),
      lastSyncReasons: _optStringList(json['lastSyncReasons']),
      lastBootstrapReasons: _optStringList(json['lastBootstrapReasons']),
      accountNumber: accountNumber,
      previousAccountNumbers: _stringList(json['previousAccountNumbers']),
      contactType: json['contactType'] == null
          ? null
          : _optStr(json['contactType']),
      status: json['status'] == null ? null : _optStr(json['status']),
    );
  }

  AuthUserZohoLink copyWith({
    String? contactId,
    String? contactPersonId,
    String? linkedAt,
    ZohoMatchStrategy? matchStrategy,
    String? syncedAt,
    List<String>? lastSyncReasons,
    List<String>? lastBootstrapReasons,
    String? accountNumber,
    List<String>? previousAccountNumbers,
    String? contactType,
    String? status,
  }) {
    return AuthUserZohoLink(
      contactId: contactId ?? this.contactId,
      contactPersonId: contactPersonId ?? this.contactPersonId,
      linkedAt: linkedAt ?? this.linkedAt,
      matchStrategy: matchStrategy ?? this.matchStrategy,
      syncedAt: syncedAt ?? this.syncedAt,
      lastSyncReasons: lastSyncReasons ?? this.lastSyncReasons,
      lastBootstrapReasons: lastBootstrapReasons ?? this.lastBootstrapReasons,
      accountNumber: accountNumber ?? this.accountNumber,
      previousAccountNumbers:
          previousAccountNumbers ?? this.previousAccountNumbers,
      contactType: contactType ?? this.contactType,
      status: status ?? this.status,
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
    if (previousAccountNumbers.isNotEmpty)
      'previousAccountNumbers': previousAccountNumbers,
    if (contactType != null) 'contactType': contactType,
    if (status != null) 'status': status,
  };
}
