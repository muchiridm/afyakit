// lib/features/tenants/services/tenant_config.dart
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

/// Injected in main(): must always be overridden.
final tenantConfigProvider = Provider<TenantConfig>((ref) {
  throw UnimplementedError('Override tenantConfigProvider in main()');
});

/// Smaller rebuild surface for common needs.
final tenantDisplayNameProvider = Provider<String>(
  (ref) => ref.watch(tenantConfigProvider).displayName,
);

typedef Json = Map<String, dynamic>;

class TenantConfig {
  static const String defaultColorHex = '#2196F3';

  final String id; // e.g., "afyakit"
  final String displayName; // e.g., "AfyaKit"
  final String primaryColorHex; // "#5E60CE"
  final String? logoPath; // asset path or URL
  final Map<String, dynamic> flags;

  const TenantConfig({
    required this.id,
    required this.displayName,
    required this.primaryColorHex,
    this.logoPath,
    this.flags = const {},
  });

  /// Convenience getter for theming.
  Color get primaryColor => colorFromHex(primaryColorHex);

  /// Feature flag helper with typing + fallback
  T flag<T>(String key, {required T orElse}) {
    final v = flags[key];
    return v is T ? v : orElse;
  }

  /// Asset JSON (your format)
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

  /// Firestore/API doc → uses provided id as source of truth.
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

  /// Flexible parser: prefer [id] param; otherwise use payload id.
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

/// "#RGB", "#RRGGBB", or "#AARRGGBB" → Color (defensive, allocation-light)
Color colorFromHex(
  String hex, {
  String fallback = TenantConfig.defaultColorHex,
}) {
  String sanitize(String s) {
    var h = s.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.startsWith('0x') || h.startsWith('0X')) h = h.substring(2);

    // Expand shorthand #RGB → RRGGBB
    if (h.length == 3) {
      h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
    }
    // Prepend opaque alpha if missing
    if (h.length == 6) h = 'FF$h';
    return h;
  }

  String h = sanitize(hex);
  int? value = int.tryParse(h, radix: 16);

  if (value == null || h.length != 8) {
    final fb = sanitize(fallback);
    value = int.tryParse(fb, radix: 16) ?? 0xFF2196F3; // last-ditch safety
  }

  return Color(value);
}
