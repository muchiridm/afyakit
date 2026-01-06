import 'package:afyakit/core/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/shared/widgets/home_screens/staff/staff_home_header.dart';
import 'package:afyakit/shared/widgets/home_screens/staff/staff_latest_activity_panel.dart';
import 'package:afyakit/shared/widgets/home_screens/staff/staff_home_actions.dart';
import 'package:afyakit/shared/widgets/home_screens/staff/staff_role_screens.dart';
import 'package:afyakit/shared/widgets/home_screens/staff/staff_modules_panel.dart';
import 'package:afyakit/shared/widgets/screens/base_screen.dart';
import 'package:flutter/material.dart';

class StaffHomeScreen extends StatelessWidget {
  const StaffHomeScreen({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final primaryRole = user.staffRoles.primaryRole;

    final Widget roleSection = switch (primaryRole) {
      StaffRole.owner || StaffRole.admin => OwnerAdminHomeSection(user: user),
      StaffRole.manager => ManagerHomeSection(user: user),
      StaffRole.pharmacist => PharmacistHomeSection(user: user),
      StaffRole.prescriber => PrescriberHomeSection(user: user),
      StaffRole.runner || StaffRole.dispatcher => LogisticsHomeSection(
        user: user,
        role: primaryRole!,
      ),
      StaffRole.staff || null => GenericStaffHomeSection(user: user),
    };

    return BaseScreen(
      scrollable: true,
      maxContentWidth: 800,
      header: const StaffHomeHeader(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StaffLatestActivityPanel(),
          const SizedBox(height: 24),

          // ✅ NEW: Enabled modules grid
          const StaffModulesPanel(),
          const SizedBox(height: 24),

          roleSection,
          const SizedBox(height: 24),

          const StaffHomeActions(),
        ],
      ),
    );
  }
}
