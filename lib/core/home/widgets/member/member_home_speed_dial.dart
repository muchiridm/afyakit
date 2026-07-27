// lib/core/home/widgets/member/member_home_speed_dial.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_speed_dial.dart';

import 'package:afyakit/features/clinical/profiles/widgets/profiles_screen.dart';
import 'package:afyakit/features/clinical/prescriptions/widgets/prescriptions_screen.dart';

class MemberHomeSpeedDial extends StatelessWidget {
  const MemberHomeSpeedDial({
    super.key,
    required this.user,
    required this.onChat,
  });

  final AuthUser? user;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final contactId = user?.contactId;

    return HomeSpeedDial(
      actions: [
        HomeSpeedDialAction(
          label: 'Add profile',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfilesScreen(
                  contactId: contactId,
                  allowExplicitContactLink: false,
                ),
              ),
            );
          },
        ),
        HomeSpeedDialAction(
          label: 'Upload prescription',
          icon: Icons.upload_file_outlined,
          onPressed: () {
            PrescriptionsScreen.open(context: context, contactId: contactId);
          },
        ),
        HomeSpeedDialAction(
          label: 'Chat',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: onChat,
        ),
      ],
    );
  }
}
