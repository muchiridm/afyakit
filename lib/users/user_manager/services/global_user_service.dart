import 'package:afyakit/users/user_manager/models/global_user_model.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';

class GlobalUserService {
  GlobalUserService(this._db);
  final FirebaseFirestore _db;

  CollectionReference<GlobalUser> get _users => _db
      .collection('users')
      .withConverter<GlobalUser>(
        fromFirestore: (snap, _) => GlobalUser.fromJson(
          snap.id,
          (snap.data() ?? <String, Object?>{}).cast<String, Object?>(),
        ),
        toFirestore: (u, _) => u.toJson(),
      );

  /// Live list of users filtered by [tenantId] (optional) and email prefix [search].
  /// Ordered by `emailLower`. Limited by [limit] (default 50).
  Stream<List<GlobalUser>> usersStream({
    String? tenantId,
    String search = '',
    int limit = 50,
  }) {
    Query<GlobalUser> q = _users.orderBy('emailLower');

    if (tenantId != null && tenantId.isNotEmpty) {
      q = q.where('tenantIds', arrayContains: tenantId);
    }

    final s = search.trim().toLowerCase();
    if (s.isNotEmpty) {
      // simple prefix search on emailLower
      final end =
          s.substring(0, s.length - 1) +
          String.fromCharCode(s.codeUnitAt(s.length - 1) + 1);
      q = q
          .where('emailLower', isGreaterThanOrEqualTo: s)
          .where('emailLower', isLessThan: end);
    }

    q = q.limit(limit);

    return q.snapshots().map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// Fetch memberships for a given user (on demand for expansion tiles).
  Future<Map<String, Map<String, Object?>>> fetchMemberships(String uid) async {
    final mems = await _db.collection('users/$uid/memberships').get();
    final out = <String, Map<String, Object?>>{};
    for (final d in mems.docs) {
      final data = d.data();
      out[d.id] = {'role': data['role'], 'active': data['active']};
    }
    return out;
  }
}
