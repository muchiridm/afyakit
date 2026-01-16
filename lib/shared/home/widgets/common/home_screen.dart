import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/shared/home/models/home_mode.dart';

import 'package:afyakit/shared/home/widgets/common/home_header.dart';
import 'package:afyakit/shared/home/widgets/member/member_latest_activity_panel.dart';
import 'package:afyakit/shared/home/widgets/staff/staff_features_panel.dart';
import 'package:afyakit/shared/home/widgets/staff/staff_latest_activity_panel.dart';

import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page_scaffold.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.mode, required this.user});

  final HomeMode mode;
  final AuthUser user;

  static const double _staffTwoColBreakpoint = 720;

  bool get _isMember => mode == HomeMode.member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPageScaffold(
      // Home scrolls as one document (header + panels)
      scrollable: true,

      // Home doesn't need a visible app bar because HomeHeader is the header.
      // AppPageScaffold requires one, so we give it a zero-height appbar.
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(0),
        child: SizedBox.shrink(),
      ),

      body: _isMember ? _buildMember(context) : _buildStaff(context),
    );
  }

  // Small helper to avoid repeating "Column + gaps"
  Widget _stack(List<Widget> children, {double gap = AppShape.gap12}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) SizedBox(height: gap),
        ],
      ],
    );
  }

  Widget _buildMember(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final targetW = math.min(c.maxWidth, AppLayout.memberPageMaxW);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: targetW,
            child: _stack([
              HomeHeader(
                mode: mode,
                greetingName: _greetingName(),
                memberId: user.accountNumber,
                showDeliveryBanner: false,
                panelWidth: targetW,
              ),
              const MemberLatestActivityPanel(),
              // optional breathing room at bottom
              const SizedBox(height: AppShape.gap12),
            ], gap: AppShape.gap12),
          ),
        );
      },
    );
  }

  Widget _buildStaff(BuildContext context) {
    return _stack([
      HomeHeader(
        mode: mode,
        showDeliveryBanner: true,
        panelWidth: AppLayout.pageMaxW,
      ),
      _buildStaffPanels(),
      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap16);
  }

  Widget _buildStaffPanels() {
    return LayoutBuilder(
      builder: (context, c) {
        final twoCol = c.maxWidth >= _staffTwoColBreakpoint;

        final latest = const StaffLatestActivityPanel();
        final features = const StaffFeaturesPanel();

        if (!twoCol) {
          return _stack([latest, features], gap: AppShape.gap12);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: features),
            const SizedBox(width: AppShape.gap12),
            Expanded(child: latest),
          ],
        );
      },
    );
  }

  String _greetingName() {
    final n = user.displayName.trim();
    return n.isNotEmpty ? n : user.phoneNumber;
  }
}
