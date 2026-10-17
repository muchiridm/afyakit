// lib/features/home/activities/feed/activity_feed_providers.dart

import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

import 'activity_feed_record.dart';
import 'activity_feed_service.dart';

final activityFeedServiceProvider = Provider<ActivityFeedService>((ref) {
  return ActivityFeedService(FirebaseFirestore.instance);
});

/// Member feed scope keyed only by the authenticated Native Contact account.
///
/// [contactId] is accepted temporarily for older widget callers but never used
/// for queries or authorisation. Remove after those callers are migrated.
class MemberActivityScope {
  const MemberActivityScope({
    this.accountNumber,
    @Deprecated('Use accountNumber; contactId is ignored.') this.contactId,
    this.limit = 20,
  });

  final String? accountNumber;
  @Deprecated('Legacy Zoho identifier; ignored for member activity.')
  final String? contactId;
  final int limit;

  String? get cleanAccountNumber {
    final value = accountNumber?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get isEmpty => cleanAccountNumber == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberActivityScope &&
          other.cleanAccountNumber == cleanAccountNumber &&
          other.limit == limit;

  @override
  int get hashCode => Object.hash(cleanAccountNumber, limit);
}

final staffActivityFeedProvider =
    StreamProvider.autoDispose<List<ActivityFeedRecord>>((ref) {
      final tenantId = ref.watch(tenantIdProvider);
      final appId = ref.watch(appIdProvider);
      final service = ref.watch(activityFeedServiceProvider);

      return service.watchStaffActivity(
        tenantId: tenantId,
        appId: appId,
        limit: 50,
      );
    });

final memberActivityFeedProvider = StreamProvider.autoDispose
    .family<List<ActivityFeedRecord>, MemberActivityScope>((ref, scope) {
      if (scope.isEmpty) {
        return Stream<List<ActivityFeedRecord>>.value(
          const <ActivityFeedRecord>[],
        );
      }

      final tenantId = ref.watch(tenantIdProvider);
      final appId = ref.watch(appIdProvider);
      final service = ref.watch(activityFeedServiceProvider);

      return service.watchAccountActivity(
        tenantId: tenantId,
        appId: appId,
        accountNumber: scope.cleanAccountNumber!,
        limit: scope.limit,
      );
    });
