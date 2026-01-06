import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/domains/models/domain_index.dart';

final domainIndexServiceProvider = Provider<DomainIndexService>((ref) {
  final db = FirebaseFirestore.instance;
  return DomainIndexService(db);
});

class DomainIndexService {
  DomainIndexService(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('domains');

  Stream<DomainIndex?> watchByHost(String host) {
    final id = host.trim().toLowerCase();
    return _col.doc(id).snapshots().map((s) {
      if (!s.exists) return null;
      return DomainIndex.fromDoc(s.id, s.data()!);
    });
  }

  Future<DomainIndex?> getByHost(String host) async {
    final id = host.trim().toLowerCase();
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return DomainIndex.fromDoc(snap.id, snap.data()!);
  }

  Future<void> upsert(DomainIndex d) async {
    await _col.doc(d.domain).set(d.toJson(), SetOptions(merge: true));
  }

  Future<void> deleteByHost(String host) async {
    await _col.doc(host.trim().toLowerCase()).delete();
  }

  /// List all domains for a tenant
  Stream<List<DomainIndex>> watchByTenant(String tenantSlug) {
    return _col
        .where('tenantSlug', isEqualTo: tenantSlug)
        .snapshots()
        .map(
          (q) =>
              q.docs.map((d) => DomainIndex.fromDoc(d.id, d.data())).toList(),
        );
  }
}
