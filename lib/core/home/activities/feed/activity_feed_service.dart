// lib/core/home/activities/feed/activity_feed_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import 'activity_feed_record.dart';

class ActivityFeedService {
  const ActivityFeedService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String tenantId) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('activity');
  }

  /// Staff feed should be chronological across all activity types.
  Stream<List<ActivityFeedRecord>> watchStaffActivity({
    required String tenantId,
    int limit = 50,
  }) {
    return _collection(tenantId)
        .orderBy('occurred_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ActivityFeedRecord.fromDoc).toList());
  }

  Stream<List<ActivityFeedRecord>> watchContactActivity({
    required String tenantId,
    required String contactId,
    int limit = 20,
  }) {
    return _collection(tenantId)
        .where('contact_id', isEqualTo: contactId)
        .orderBy('occurred_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ActivityFeedRecord.fromDoc).toList());
  }

  Stream<List<ActivityFeedRecord>> watchAccountActivity({
    required String tenantId,
    required String accountNumber,
    int limit = 20,
  }) {
    return _collection(tenantId)
        .where('account_number', isEqualTo: accountNumber)
        .orderBy('occurred_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ActivityFeedRecord.fromDoc).toList());
  }
}
