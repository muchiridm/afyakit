// lib/core/home/widgets/staff/staff_home_speed_dial.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_speed_dial.dart';

import 'package:afyakit/features/clinical/profiles/widgets/profiles_screen.dart';
import 'package:afyakit/features/clinical/prescriptions/widgets/prescriptions_screen.dart';
import 'package:afyakit/features/retail/contacts/widgets/contacts_screen.dart';

class StaffHomeSpeedDial extends StatelessWidget {
  const StaffHomeSpeedDial({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeSpeedDial(
      actions: [
        HomeSpeedDialAction(
          label: 'Add profile',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const ProfilesScreen(allowExplicitContactLink: true),
              ),
            );
          },
        ),
        HomeSpeedDialAction(
          label: 'Upload prescription',
          icon: Icons.upload_file_outlined,
          onPressed: () {
            PrescriptionsScreen.open(
              context: context,
              forceProfilePickerMode: true,
            );
          },
        ),
        HomeSpeedDialAction(
          label: 'Add contact / customer',
          icon: Icons.person_add_outlined,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ContactsScreen()),
            );
          },
        ),
      ],
    );
  }
}
