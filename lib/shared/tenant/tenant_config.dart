import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

typedef Json = Map<String, dynamic>;

class TenantConfig {
  final String id;
  final String displayName; // used for app title
  final String primaryColorHex; // "#RRGGBB"
  final String logoAsset; // asset path for logos
  final Map<String, dynamic> flags;

  const TenantConfig({
    required this.id,
    required this.displayName,
    required this.primaryColorHex,
    required this.logoAsset,
    required this.flags,
  });

  factory TenantConfig.fromJson(Json j) => TenantConfig(
    id: j['id'],
    displayName: j['displayName'],
    primaryColorHex: j['primaryColor'],
    logoAsset: j['logoPath'],
    flags: (j['flags'] ?? {}) as Json,
  );
}

Future<TenantConfig> loadTenantConfig(String tenantId) async {
  final raw = await rootBundle.loadString('assets/tenants/$tenantId.json');
  return TenantConfig.fromJson(json.decode(raw) as Json);
}
