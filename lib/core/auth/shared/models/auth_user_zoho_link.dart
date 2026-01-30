class AuthUserZohoLink {
  final String contactId;
  final String? contactPersonId;

  /// ISO timestamp string (backend uses serverTimestamp; API returns ISO).
  final String? linkedAt;

  /// How the link was established.
  /// Backend guarantees a value (defaults to "manual").
  final String matchStrategy; // 'phone' | 'email' | 'manual' | 'created'

  /// Optional sync metadata
  final String? syncedAt;
  final List<String>? lastSyncReasons;

  const AuthUserZohoLink({
    required this.contactId,
    this.contactPersonId,
    this.linkedAt,
    this.matchStrategy = 'manual',
    this.syncedAt,
    this.lastSyncReasons,
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
    return out.where(seen.add).toList();
  }

  factory AuthUserZohoLink.fromMap(Map<String, dynamic> json) {
    final contactId = _cleanStr(json['contactId']);
    if (contactId.isEmpty) {
      throw ArgumentError('AuthUserZohoLink requires contactId');
    }

    final strat = _cleanStr(json['matchStrategy']).toLowerCase();
    final matchStrategy =
        (strat == 'phone' ||
            strat == 'email' ||
            strat == 'manual' ||
            strat == 'created')
        ? strat
        : 'manual';

    return AuthUserZohoLink(
      contactId: contactId,
      contactPersonId: _optStr(json['contactPersonId']),
      linkedAt: _optStr(json['linkedAt']),
      matchStrategy: matchStrategy,
      syncedAt: _optStr(json['syncedAt']),
      lastSyncReasons: _optStringList(json['lastSyncReasons']),
    );
  }

  Map<String, dynamic> toMap() => {
    'contactId': contactId,
    'matchStrategy': matchStrategy,
    if (contactPersonId != null) 'contactPersonId': contactPersonId,
    if (linkedAt != null) 'linkedAt': linkedAt,
    if (syncedAt != null) 'syncedAt': syncedAt,
    if (lastSyncReasons != null && lastSyncReasons!.isNotEmpty)
      'lastSyncReasons': lastSyncReasons,
  };
}
