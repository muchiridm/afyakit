// lib/config/tenant_config.dart
import 'dart:ui';

typedef Json = Map<String, dynamic>;

class TenantConfig {
  final String id; // doc id (e.g., "afyakit")
  final String displayName; // "AfyaKit"
  final String primaryColorHex; // "#5E60CE"
  final String? logoPath; // optional (asset or URL)
  final Map<String, dynamic> flags;

  const TenantConfig({
    required this.id,
    required this.displayName,
    required this.primaryColorHex,
    this.logoPath,
    this.flags = const {},
  });

  // Asset JSON (your current format)
  factory TenantConfig.fromJson(Json j) => TenantConfig(
    id: j['id'] as String,
    displayName: j['displayName'] as String,
    primaryColorHex: (j['primaryColorHex'] ?? j['primaryColor']) as String,
    logoPath: j['logoPath'] as String?,
    flags: Map<String, dynamic>.from(j['flags'] ?? const {}),
  );

  // Firestore doc (matches your screenshot)
  factory TenantConfig.fromFirestore(String id, Json d) => TenantConfig(
    id: id,
    displayName: (d['displayName'] as String?) ?? id,
    primaryColorHex:
        (d['primaryColorHex'] as String?) ??
        (d['primaryColor'] as String?) ??
        '#2196F3',
    logoPath: d['logoPath'] as String?, // optional
    flags: Map<String, dynamic>.from(d['flags'] ?? const {}),
  );
}

// Helper: "#RRGGBB"/"#AARRGGBB" → Color

Color colorFromHex(String hex, {String fallback = '#2196F3'}) {
  String h = hex.trim().toUpperCase().replaceAll('#', '').replaceAll('0X', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) {
    h = fallback.replaceAll('#', '').toUpperCase();
    if (h.length == 6) h = 'FF$h';
  }
  return Color(int.parse(h, radix: 16));
}
