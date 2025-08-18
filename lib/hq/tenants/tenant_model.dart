// lib/tenants/tenant_model.dart
import 'package:afyakit/shared/utils/firestore_instance.dart';

class Tenant {
  final String id;
  final String slug;
  final String displayName;
  final String primaryColor;
  final String? logoPath;
  final Map<String, dynamic> flags;
  final String status; // 'active' | 'suspended'
  final DateTime? createdAt;

  // 👇 NEW: canonical ownership (single source of truth)
  final String? ownerUid;
  final String? ownerEmail; // convenience (optional)

  const Tenant({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.primaryColor,
    this.logoPath,
    this.flags = const {},
    this.status = 'active',
    this.createdAt,
    this.ownerUid,
    this.ownerEmail,
  });

  factory Tenant.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final id = doc.id;
    return Tenant(
      id: id,
      slug: (d['slug'] ?? id).toString(),
      displayName: (d['displayName'] ?? id).toString(),
      primaryColor: (d['primaryColor'] ?? '#1565C0').toString(),
      logoPath: _normalizeLogoPath(d['logoPath']),
      flags: Map<String, dynamic>.from(d['flags'] as Map? ?? const {}),
      status: (d['status'] ?? 'active').toString(),
      createdAt: _parseCreatedAt(d['createdAt']),
      ownerUid: (d['ownerUid'] as String?)?.trim(),
      ownerEmail: (d['ownerEmail'] as String?)?.trim(),
    );
  }

  factory Tenant.fromMap(String id, Map<String, dynamic> d) {
    return Tenant(
      id: id,
      slug: (d['slug'] ?? id).toString(),
      displayName: (d['displayName'] ?? id).toString(),
      primaryColor: (d['primaryColor'] ?? '#1565C0').toString(),
      logoPath: _normalizeLogoPath(d['logoPath']),
      flags: Map<String, dynamic>.from(d['flags'] as Map? ?? const {}),
      status: (d['status'] ?? 'active').toString(),
      createdAt: _parseCreatedAt(d['createdAt']),
      ownerUid: (d['ownerUid'] as String?)?.trim(),
      ownerEmail: (d['ownerEmail'] as String?)?.trim(),
    );
  }

  static String? _normalizeLogoPath(dynamic v) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static DateTime? _parseCreatedAt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}
