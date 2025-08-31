import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:afyakit/hq/core/tenants/utils/color.dart';

typedef Json = Map<String, dynamic>;

class TenantConfig {
  static const String defaultColorHex = '#2196F3';

  final String id; // e.g. "afyakit"
  final String displayName; // e.g. "AfyaKit"
  final String primaryColorHex; // e.g. "#5E60CE"
  final String? logoPath; // asset path or URL
  final Map<String, dynamic> flags;

  const TenantConfig({
    required this.id,
    required this.displayName,
    required this.primaryColorHex,
    this.logoPath,
    this.flags = const {},
  });

  /// Theming convenience
  Color get primaryColor => colorFromHex(primaryColorHex);

  /// Typed feature flag helper with fallback
  T flag<T>(String key, {required T orElse}) {
    final v = flags[key];
    return v is T ? v : orElse;
  }

  /// Parse from generic JSON (e.g. assets)
  factory TenantConfig.fromJson(Json j) => TenantConfig(
    id: (j['id'] ?? '').toString(),
    displayName: (j['displayName'] ?? j['name'] ?? '').toString(),
    primaryColorHex:
        (j['primaryColorHex'] as String?) ??
        (j['primaryColor'] as String?) ??
        defaultColorHex,
    logoPath: (j['logoPath'] as String?) ?? (j['logo'] as String?),
    flags: Map<String, dynamic>.from(j['flags'] ?? const {}),
  );

  /// Parse from Firestore (id provided separately)
  factory TenantConfig.fromFirestore(String id, Json d) => TenantConfig(
    id: id,
    displayName: (d['displayName'] ?? d['name'] ?? id).toString(),
    primaryColorHex:
        (d['primaryColorHex'] as String?) ??
        (d['primaryColor'] as String?) ??
        defaultColorHex,
    logoPath: d['logoPath'] as String?,
    flags: Map<String, dynamic>.from(d['flags'] ?? const {}),
  );

  /// Flexible parser that prefers explicit [id]
  factory TenantConfig.fromAny(Json data, {String? id}) {
    final explicitId = (id != null && id.trim().isNotEmpty) ? id : null;
    final sourceId = explicitId ?? (data['id'] ?? '').toString();
    if (sourceId.isEmpty) {
      throw ArgumentError('TenantConfig.fromAny requires an id.');
    }
    return explicitId != null
        ? TenantConfig.fromFirestore(sourceId, data)
        : TenantConfig.fromJson(data);
  }

  TenantConfig copyWith({
    String? id,
    String? displayName,
    String? primaryColorHex,
    String? logoPath,
    Map<String, dynamic>? flags,
  }) {
    return TenantConfig(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      logoPath: logoPath ?? this.logoPath,
      flags: flags ?? this.flags,
    );
  }

  Json toJson() => <String, dynamic>{
    'id': id,
    'displayName': displayName,
    'primaryColorHex': primaryColorHex,
    if (logoPath != null) 'logoPath': logoPath,
    if (flags.isNotEmpty) 'flags': flags,
  };

  @override
  String toString() =>
      'TenantConfig(id=$id, name=$displayName, color=$primaryColorHex, logo=$logoPath, flags=${flags.keys.toList()})';

  static const DeepCollectionEquality _deepEq = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TenantConfig &&
          id == other.id &&
          displayName == other.displayName &&
          primaryColorHex == other.primaryColorHex &&
          logoPath == other.logoPath &&
          _deepEq.equals(flags, other.flags);

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    primaryColorHex,
    logoPath,
    _deepEq.hash(flags),
  );
}
