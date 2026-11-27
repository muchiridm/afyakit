import 'package:flutter_test/flutter_test.dart';
import 'package:afyakit/features/clinical/prescriptions/prescription_model.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

void main() {
  test(
    'reference projection has no clinical fields and carries no implicit read/review rights',
    () {
      final p = Prescription.fromJson({
        'prescription_id': 'rx',
        'profile_id': 'p',
        'app_id': 'app',
        'status': 'uploaded',
        'is_active': true,
        'allowed_actions': ['reference'],
        'allowed_statuses': [],
      });
      expect(p.can('reference'), true);
      for (final action in ['read', 'upload', 'review', 'archive']) {
        expect(p.can(action), false);
      }
      expect(p.fileName, isEmpty);
      expect(p.storagePath, isEmpty);
      expect(p.note, isNull);
      expect(p.allowedStatuses, isEmpty);
    },
  );
  test(
    'missing backend resource actions fail closed; transitions come from server',
    () {
      final p = Prescription.fromJson({
        'prescription_id': 'rx',
        'profile_id': 'p',
        'status': 'uploaded',
        'is_active': true,
      });
      expect(p.allowedActions, isEmpty);
      final reviewed = Prescription.fromJson({
        'prescription_id': 'rx',
        'profile_id': 'p',
        'status': 'verified',
        'is_active': true,
        'allowed_actions': ['read', 'review'],
        'allowed_statuses': ['expired'],
      });
      expect(reviewed.allowedStatuses, [PrescriptionStatus.expired]);
    },
  );
  test(
    'session permissions are app scoped, do not inherit roles and are not persisted as account authority',
    () {
      final user = AuthUser.fromMap({
        'uid': 'u',
        'tenantId': 't',
        'status': 'active',
        'appMembershipsByApp': {
          'one': {'status': 'active'},
          'two': {'status': 'active'},
        },
        'staffRolesByApp': {
          'one': ['owner'],
          'two': ['pharmacist'],
        },
        'appAccess': {'appId': 'one'},
        'effectivePermissions': ['clinical.prescription.reference'],
      });
      expect(
        user.forApp('one').hasPermission('clinical.prescription.reference'),
        true,
      );
      expect(
        user.forApp('one').hasPermission('clinical.prescription.read'),
        false,
      );
      expect(
        user.forApp('two').hasPermission('clinical.prescription.reference'),
        false,
      );
      expect(user.toMap().containsKey('effectivePermissions'), false);
    },
  );
}
