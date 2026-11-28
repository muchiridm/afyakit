import 'package:flutter_test/flutter_test.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/features/hq/users/all_users/controllers/user_editor_controller.dart';

void main() {
  test(
    'professional roles are distinct and cannot be assigned in general editors',
    () {
      expect(StaffRole.tryParse('doctor'), isNull);
      expect(StaffRole.tryParse('nurse'), StaffRole.nurse);
      for (final role in StaffRole.values.where((r) => r.isProfessional)) {
        expect(StaffRole.owner.canAssignRole(role), isFalse);
        expect(StaffRole.admin.canAssignRole(role), isFalse);
      }
      for (final role in [
        StaffRole.clinician,
        StaffRole.nurse,
        StaffRole.technician,
      ]) {
        expect(role.capabilities, isEmpty);
      }
    },
  );
  test(
    'administrative editing preserves additive independent functional assignments',
    () {
      expect(
        mergeAdministrativeRoles(
          ['admin', 'pharmacist', 'nurse', 'runner'],
          ['manager'],
        ),
        ['pharmacist', 'nurse', 'runner', 'manager'],
      );
      expect(mergeAdministrativeRoles(['owner', 'technician'], []), [
        'technician',
      ]);
    },
  );
}
