//lib/core/auth_users/extensions/user_badge_x.dart

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';

enum UserBadge { doctor, pharmacist, rider, agent }

UserBadge? badgeFromString(String? v) {
  switch ((v ?? '').trim().toLowerCase()) {
    case 'doctor':
      return UserBadge.doctor;
    case 'pharmacist':
      return UserBadge.pharmacist;
    case 'rider':
      return UserBadge.rider;
    case 'agent':
      return UserBadge.agent;
    default:
      return null;
  }
}

List<UserBadge> badgesFromAny(dynamic v) {
  if (v is! List) return const [];
  return v
      .map((e) => badgeFromString(e?.toString()))
      .whereType<UserBadge>()
      .toList(growable: false);
}

extension UserBadgesX on AuthUser {
  bool get isDoctor => badges.contains(UserBadge.doctor);
  bool get isPharmacist => badges.contains(UserBadge.pharmacist);
  bool get isRider => badges.contains(UserBadge.rider);
  bool get isAgent => badges.contains(UserBadge.agent);
}
