// lib/core/domains/services/domain_index_service.dart

// Read-only global hostname ownership lookup. Writes belong to the HQ API.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/domains/models/domain_index.dart';

final domainIndexServiceProvider = Provider<DomainIndexService>((ref) {
  return DomainIndexService(FirebaseFirestore.instance);
});

class DomainIndexService {
  DomainIndexService(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('domains');

  Stream<DomainIndex?> watchByHost(String host) {
    final id = host.trim().toLowerCase();
    return _col
        .doc(id)
        .snapshots()
        .map(
          (snap) =>
              snap.exists ? DomainIndex.fromDoc(snap.id, snap.data()!) : null,
        );
  }

  Future<DomainIndex?> getByHost(String host) async {
    final id = host.trim().toLowerCase();
    final snap = await _col.doc(id).get();
    return snap.exists ? DomainIndex.fromDoc(snap.id, snap.data()!) : null;
  }

  Stream<List<DomainIndex>> watchByTenant(String tenantId) {
    return _col
        .where('tenantId', isEqualTo: tenantId.trim().toLowerCase())
        .snapshots()
        .map(
          (query) => query.docs
              .map((doc) => DomainIndex.fromDoc(doc.id, doc.data()))
              .toList(),
        );
  }
}
