import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/hq/catalog/medication/catalog_medication.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final catalogMedicationServiceProvider = Provider<CatalogMedicationService>(
  (ref) => CatalogMedicationService(),
);

const String kCatalogDrugsPath = 'catalog_drugs';

class _FKeys {
  static const rxcui = 'rxcui';
  static const drugId = 'drugId'; // mirror of rxcui
  static const name = 'name';
  static const nameLower = 'nameLower';
  static const synonyms = 'synonyms';
  static const routes = 'routes';
  static const atc = 'atc'; // with l5: {code,name}
  static const updatedAt = 'updatedAt';
  static const searchTerms = 'searchTerms';
}

class CatalogMedicationService {
  final FirebaseFirestore _db;
  CatalogMedicationService({FirebaseFirestore? firestore})
    : _db = firestore ?? db;

  DocumentReference<Map<String, dynamic>> docRef(String id) =>
      _db.doc('$kCatalogDrugsPath/$id');

  CollectionReference<Map<String, dynamic>> colRef() =>
      _db.collection(kCatalogDrugsPath);

  Stream<CatalogMedication?> watchById(String id) {
    return docRef(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return CatalogMedication.fromMap(snap.id, data);
    });
  }

  Future<CatalogMedication?> getById(String id) async {
    final snap = await docRef(id).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return CatalogMedication.fromMap(snap.id, data);
  }

  Future<List<CatalogMedication>> getManyByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final snaps = await Future.wait(ids.map((id) => docRef(id).get()));
    return snaps
        .where((s) => s.exists && s.data() != null)
        .map((s) => CatalogMedication.fromMap(s.id, s.data()!))
        .toList();
  }

  /// Search strategy:
  /// 1) nameLower prefix
  /// 2) searchTerms array-contains (synonyms, routes, ATC codes, RXCUI tokens)
  /// 3) exact id (RXCUI) match fallback
  Future<List<CatalogMedication>> search({
    required String query,
    int limit = 20,
  }) async {
    final qRaw = query.trim();
    if (qRaw.isEmpty) {
      debugPrint('🔎[CatalogSvc] search skipped (empty)');
      return const [];
    }

    final q = qRaw.toLowerCase();
    debugPrint('🔎[CatalogSvc] search("$qRaw") → lower="$q", limit=$limit');

    final results = <CatalogMedication>[];
    final seen = <String>{};

    // 1) nameLower prefix (requires single-field index on nameLower)
    try {
      final snap = await colRef()
          .orderBy(_FKeys.nameLower)
          .startAt([q])
          .endAt(['$q\uf8ff'])
          .limit(limit)
          .get();

      debugPrint('  • nameLower prefix → ${snap.docs.length} docs');
      for (final d in snap.docs) {
        results.add(CatalogMedication.fromMap(d.id, d.data()));
        seen.add(d.id);
      }
    } catch (e) {
      // This fails if you don't have an index on nameLower.
      debugPrint(
        '  ⚠️ nameLower prefix query failed (likely missing index): $e',
      );
    }

    // 2) token match (requires precomputed searchTerms)
    if (results.length < limit) {
      final remain = limit - results.length;
      final snap = await colRef()
          .where(_FKeys.searchTerms, arrayContains: q)
          .limit(remain)
          .get();
      debugPrint(
        '  • searchTerms arrayContains("$q") → ${snap.docs.length} docs',
      );
      for (final d in snap.docs) {
        if (seen.add(d.id)) {
          results.add(CatalogMedication.fromMap(d.id, d.data()));
        }
      }
    }

    // 3) exact RXCUI (doc id) match
    if (results.length < limit && RegExp(r'^\d+$').hasMatch(qRaw)) {
      final snap = await docRef(qRaw).get();
      final ok = snap.exists && snap.data() != null;
      debugPrint('  • exact RXCUI("$qRaw") → ${ok ? "hit" : "miss"}');
      if (ok && seen.add(snap.id)) {
        results.add(CatalogMedication.fromMap(snap.id, snap.data()!));
      }
    }

    debugPrint('✅[CatalogSvc] search done → returning ${results.length} items');
    return results.take(limit).toList();
  }

  /// Optional: rebuild nameLower/searchTerms locally if needed.
  Future<void> ensureSearchTerms(String id) async {
    final snap = await docRef(id).get();
    if (!snap.exists) {
      debugPrint('🛠[CatalogSvc] ensureSearchTerms("$id") → doc missing');
      return;
    }
    final m = snap.data()!;
    final name = (m[_FKeys.name] as String? ?? '');
    final synonyms = ((m[_FKeys.synonyms] as List?) ?? const []).cast<String>();
    final routes = ((m[_FKeys.routes] as List?) ?? const []).cast<String>();
    final atcCode =
        ((m[_FKeys.atc] as Map?)?['l5'] as Map?)?['code'] as String?;
    final rxcui = (m[_FKeys.rxcui] ?? m[_FKeys.drugId] ?? '') as String? ?? '';

    final tokens = _buildTokens(
      name: name,
      synonyms: synonyms,
      routes: routes,
      atcCode: atcCode,
      rxcui: rxcui,
    );

    await snap.reference.set({
      _FKeys.nameLower: name.toLowerCase(),
      _FKeys.searchTerms: tokens,
      _FKeys.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint(
      '🛠[CatalogSvc] ensureSearchTerms("$id") → nameLower="${name.toLowerCase()}", '
      'tokens=${tokens.length}',
    );
  }

  /// One-off helper to backfill entire collection (see section B).
  Future<int> backfillAllSearchTerms({int batchSize = 300}) async {
    debugPrint('🛠[CatalogSvc] backfillAllSearchTerms() start…');
    var updated = 0;
    QueryDocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      Query<Map<String, dynamic>> q = colRef()
          .orderBy(FieldPath.documentId)
          .limit(batchSize);
      if (last != null) q = q.startAfterDocument(last);
      final page = await q.get();
      if (page.docs.isEmpty) break;

      for (final d in page.docs) {
        final m = d.data();
        final name = (m[_FKeys.name] as String? ?? '');
        final synonyms = ((m[_FKeys.synonyms] as List?) ?? const [])
            .cast<String>();
        final routes = ((m[_FKeys.routes] as List?) ?? const []).cast<String>();
        final atcCode =
            ((m[_FKeys.atc] as Map?)?['l5'] as Map?)?['code'] as String?;
        final rxcui =
            (m[_FKeys.rxcui] ?? m[_FKeys.drugId] ?? '') as String? ?? '';

        final tokens = _buildTokens(
          name: name,
          synonyms: synonyms,
          routes: routes,
          atcCode: atcCode,
          rxcui: rxcui,
        );

        await d.reference.set({
          _FKeys.nameLower: name.toLowerCase(),
          _FKeys.searchTerms: tokens,
          _FKeys.updatedAt: FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        updated++;
      }

      last = page.docs.last;
      debugPrint('  …backfill progress → $updated docs updated');
    }

    debugPrint('✅[CatalogSvc] backfill complete → $updated docs updated');
    return updated;
  }
}

List<String> _buildTokens({
  required String name,
  required List<String> synonyms,
  required List<String> routes,
  String? atcCode,
  String? rxcui,
}) {
  final set = <String>{};

  void add(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return;
    set.add(t); // full token for exact contains
    // short prefixes for quick wins while you type
    if (t.length >= 3) set.add(t.substring(0, 3));
    if (t.length >= 4) set.add(t.substring(0, 4));
  }

  add(name);
  for (final s in synonyms) {
    add(s);
  }
  for (final s in routes) {
    add(s);
  }
  if (atcCode != null) add(atcCode);
  if (rxcui != null) add(rxcui);

  return set.toList();
}
