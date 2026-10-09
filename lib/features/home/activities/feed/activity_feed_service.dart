// lib/features/home/activities/feed/activity_feed_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

  /// Chronological staff activity for one application.
  ///
  /// Tenant membership alone does not grant staff access.
  /// Firestore rules enforce the user's staffRolesByApp grant.
  Stream<List<ActivityFeedRecord>> watchStaffActivity({
    required String tenantId,
    required String appId,
    int limit = 50,
  }) {
    debugPrint(
      '🔍 [activity][STAFF] '
      'tenant=$tenantId app=$appId limit=$limit',
    );

    return _collection(tenantId)
        .where('app_id', isEqualTo: appId)
        .orderBy('occurred_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          debugPrint(
            '✅ [activity][STAFF] '
            'received=${snap.docs.length} '
            'tenant=$tenantId app=$appId',
          );

          return snap.docs
              .map(ActivityFeedRecord.fromDoc)
              .toList(growable: false);
        })
        .handleError((Object error, StackTrace stack) {
          debugPrint(
            '❌ [activity][STAFF] '
            'tenant=$tenantId app=$appId '
            'error=$error',
          );

          Error.throwWithStackTrace(error, stack);
        });
  }

  /// Member activity associated with a contact ID
  /// within one application.
  ///
  /// Contact identifiers are deliberately excluded from logs.
  Stream<List<ActivityFeedRecord>> watchContactActivity({
    required String tenantId,
    required String appId,
    required String contactId,
    int limit = 20,
  }) {
    debugPrint(
      '🔍 [activity][MEMBER-CONTACT] '
      'tenant=$tenantId app=$appId limit=$limit '
      'subscription started',
    );

    return _collection(tenantId)
        .where('app_id', isEqualTo: appId)
        .where('contact_id', isEqualTo: contactId)
        .orderBy('occurred_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          debugPrint(
            '✅ [activity][MEMBER-CONTACT] '
            'received=${snap.docs.length} '
            'tenant=$tenantId app=$appId',
          );

          return snap.docs
              .map(ActivityFeedRecord.fromDoc)
              .toList(growable: false);
        })
        .handleError((Object error, StackTrace stack) {
          debugPrint(
            '❌ [activity][MEMBER-CONTACT] '
            'tenant=$tenantId app=$appId '
            'error=$error',
          );

          Error.throwWithStackTrace(error, stack);
        });
  }

  /// Member activity associated with an account number
  /// within one application.
  ///
  /// Account numbers are deliberately excluded from logs.
  Stream<List<ActivityFeedRecord>> watchAccountActivity({
    required String tenantId,
    required String appId,
    required String accountNumber,
    int limit = 20,
  }) {
    debugPrint(
      '🔍 [activity][MEMBER-ACCOUNT] '
      'tenant=$tenantId app=$appId limit=$limit '
      'subscription started',
    );

    return _collection(tenantId)
        .where('app_id', isEqualTo: appId)
        .where('account_number', isEqualTo: accountNumber)
        .orderBy('occurred_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          debugPrint(
            '✅ [activity][MEMBER-ACCOUNT] '
            'received=${snap.docs.length} '
            'tenant=$tenantId app=$appId',
          );

          return snap.docs
              .map(ActivityFeedRecord.fromDoc)
              .toList(growable: false);
        })
        .handleError((Object error, StackTrace stack) {
          debugPrint(
            '❌ [activity][MEMBER-ACCOUNT] '
            'tenant=$tenantId app=$appId '
            'error=$error',
          );

          Error.throwWithStackTrace(error, stack);
        });
  }
}
