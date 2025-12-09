// lib/shared/widgets/home_screens/member/member_home_screen.dart

import 'package:afyakit/modules/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/shared/widgets/home_screens/member/member_home_header.dart';
import 'package:afyakit/shared/widgets/home_screens/member/member_latest_activity_panel.dart';
import 'package:afyakit/shared/widgets/screens/base_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseScreen(
      scrollable: true,
      maxContentWidth: 800,
      header: MemberHomeHeader(user: user),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberLatestActivityPanel(),
          SizedBox(height: 24),
          // TODO: later → MemberHomeActions (Orders, RX, Chat...)
        ],
      ),
    );
  }
}
