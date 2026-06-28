// lib/core/home/activities/feed/activity_feed_providers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import 'activity_feed_record.dart';
import 'activity_feed_service.dart';

final activityFeedServiceProvider = Provider<ActivityFeedService>((ref) {
  return ActivityFeedService(FirebaseFirestore.instance);
});

class MemberActivityScope {
  const MemberActivityScope({
    required this.contactId,
    required this.accountNumber,
    this.limit = 20,
  });

  final String? contactId;
  final String? accountNumber;
  final int limit;

  String? get cleanContactId {
    final id = contactId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  String? get cleanAccountNumber {
    final value = accountNumber?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  bool get isEmpty => cleanContactId == null && cleanAccountNumber == null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemberActivityScope &&
            other.cleanContactId == cleanContactId &&
            other.cleanAccountNumber == cleanAccountNumber &&
            other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(cleanContactId, cleanAccountNumber, limit);
}

final staffActivityFeedProvider =
    StreamProvider.autoDispose<List<ActivityFeedRecord>>((ref) {
      final tenantId = ref.watch(tenantIdProvider);
      final service = ref.watch(activityFeedServiceProvider);

      return service.watchStaffActivity(tenantId: tenantId, limit: 50);
    });

final memberActivityFeedProvider = StreamProvider.autoDispose
    .family<List<ActivityFeedRecord>, MemberActivityScope>((ref, scope) {
      if (scope.isEmpty) {
        return Stream<List<ActivityFeedRecord>>.value(
          const <ActivityFeedRecord>[],
        );
      }

      final tenantId = ref.watch(tenantIdProvider);
      final service = ref.watch(activityFeedServiceProvider);

      final contactId = scope.cleanContactId;
      if (contactId != null) {
        return service.watchContactActivity(
          tenantId: tenantId,
          contactId: contactId,
          limit: scope.limit,
        );
      }

      return service.watchAccountActivity(
        tenantId: tenantId,
        accountNumber: scope.cleanAccountNumber!,
        limit: scope.limit,
      );
    });
