// lib/shared/home/widgets/common/home_screen.dart

import 'dart:math' as math;

import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/shared/home/models/home_mode.dart';

import 'package:afyakit/shared/home/widgets/common/home_header.dart';
import 'package:afyakit/shared/home/widgets/member/member_latest_activity_panel.dart';
import 'package:afyakit/shared/home/widgets/staff/staff_features_panel.dart';
import 'package:afyakit/shared/home/widgets/staff/staff_latest_activity_panel.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.mode, required this.user});

  final HomeMode mode;
  final AuthUser user;

  static const double _maxW = 820;
  static const EdgeInsets _pagePad = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  // ✅ Member mode should breathe more than staff tiles.
  // - On phone: full width
  // - On desktop: cap (still centered)
  static const double _memberMaxW = 640;

  bool get _isMember => mode == HomeMode.member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxW),
            child: SingleChildScrollView(
              child: Padding(
                padding: _pagePad,
                child: _isMember ? _buildMember(context) : _buildStaff(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Member: responsive single column (centered), grows up to _memberMaxW
  // ─────────────────────────────────────────────────────────────
  Widget _buildMember(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final targetW = math.min(c.maxWidth, _memberMaxW);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: targetW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeHeader(
                  mode: mode,
                  greetingName: _greetingName(),
                  memberId: user.accountNumber,
                  showDeliveryBanner: false,
                  panelWidth: targetW, // keeps header internals consistent
                ),
                const SizedBox(height: 12),
                const MemberLatestActivityPanel(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Staff: full-width header (within _maxW), then responsive 1/2-col grid
  // ─────────────────────────────────────────────────────────────
  Widget _buildStaff(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeHeader(
          mode: mode,
          showDeliveryBanner: true,
          panelWidth: _maxW, // “full width” within the page container
        ),
        const SizedBox(height: 16),
        _buildStaffGrid(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStaffGrid() {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;

        // Two columns on wide layouts; one column otherwise.
        final twoCol = c.maxWidth >= 720;
        final tileW = twoCol ? (c.maxWidth - gap) / 2 : c.maxWidth;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(width: tileW, child: const StaffLatestActivityPanel()),
            SizedBox(width: tileW, child: const StaffFeaturesPanel()),
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
