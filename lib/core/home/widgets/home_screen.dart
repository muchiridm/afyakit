// lib/core/home/widgets/home_screen.dart

import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/widgets/components/home_header.dart';
import 'package:afyakit/core/home/widgets/member/member_latest_activity_panel.dart';
import 'package:afyakit/core/home/widgets/staff/staff_features_panel.dart';
import 'package:afyakit/core/home/widgets/staff/staff_latest_activity_panel.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.realEntry,
    required this.effectiveEntry,
    required this.user,
  });

  /// Real identity in this tenant (guest/member/staff)
  final EntryMode realEntry;

  /// What surface we are showing (guest/member/staff),
  /// allows staff to "view as member".
  final EntryMode effectiveEntry;

  /// Nullable because guests exist.
  final AuthUser? user;

  static const double _staffTwoColBreakpoint = 720;

  bool get _isRealMember => realEntry == EntryMode.member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      scrollable: true,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(0),
        child: SizedBox.shrink(),
      ),
      maxWidth: AppLayout.pageMaxW,
      padding: AppLayout.pagePadding,
      body: switch (effectiveEntry) {
        EntryMode.guest => _buildGuest(context),
        EntryMode.member => _buildMemberSurface(context),
        EntryMode.staff => _buildStaffSurface(context),
      },
    );
  }

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

  // ─────────────────────────────────────────────
  // Guest surface (general)
  // Only:
  // - Search (tap -> Catalog)
  // - Chat with pharmacist (CTA)
  // ─────────────────────────────────────────────
  Widget _buildGuest(BuildContext context) {
    return _stack([
      HomeHeader(
        entry: EntryMode.guest,
        greetingName: 'Guest',
        memberId: null,
        showDeliveryBanner: false,
        panelWidth: AppLayout.pageMaxW,
      ),

      const SizedBox(height: AppShape.gap8),

      _GuestSearchHero(
        onSearch: (q) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CatalogScreen(
                initialQuery: q.isEmpty ? null : q,
                autofocusSearch: true,
              ),
            ),
          );
        },
        onBrowse: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CatalogScreen(autofocusSearch: true),
            ),
          );
        },
        onChatTap: () {
          _snack(context, 'Chat with pharmacist (TODO)');
        },
      ),

      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap12);
  }

  // ─────────────────────────────────────────────
  // Member surface (individual)
  // ─────────────────────────────────────────────
  Widget _buildMemberSurface(BuildContext context) {
    final greeting = _greetingName();
    final memberId = _memberIdOrNull();

    return _stack([
      HomeHeader(
        entry: effectiveEntry,
        greetingName: greeting,
        memberId: memberId,
        showDeliveryBanner: false,
        panelWidth: AppLayout.pageMaxW,
      ),

      // ✅ Only real members should see *their* activity.
      if (_isRealMember && user != null) const MemberLatestActivityPanel(),

      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap12);
  }

  // ─────────────────────────────────────────────
  // Staff surface (staff tools)
  // ─────────────────────────────────────────────
  Widget _buildStaffSurface(BuildContext context) {
    return _stack([
      HomeHeader(
        entry: EntryMode.staff,
        greetingName: _greetingName(),
        memberId: null,
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

  String? _greetingName() {
    if (user == null) return 'Guest';
    final n = user!.displayName?.trim();
    return (n != null && n.isNotEmpty) ? n : user!.phoneNumber;
  }

  String? _memberIdOrNull() {
    if (!_isRealMember || user == null) return null;
    return user!.accountNumber;
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }
}

// ─────────────────────────────────────────────
// Guest widgets (simple like Google)
// ─────────────────────────────────────────────

// Inside: lib/core/home/widgets/home_screen.dart
// (Only showing the guest parts + widget — drop into your existing file)

class _GuestSearchHero extends StatefulWidget {
  const _GuestSearchHero({
    required this.onSearch,
    required this.onBrowse,
    required this.onChatTap,
  });

  final void Function(String query) onSearch;
  final VoidCallback onBrowse;
  final VoidCallback onChatTap;

  @override
  State<_GuestSearchHero> createState() => _GuestSearchHeroState();
}

class _GuestSearchHeroState extends State<_GuestSearchHero> {
  final _c = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Autofocus after first frame (safer than autofocus:true)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _c.text.trim();
    widget.onSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search bar
            Material(
              elevation: 1.5,
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.surface,
              child: TextField(
                controller: _c,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Search medicines, brands, conditions…',
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: _submit,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onChatTap,
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Chat pharmacist'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onBrowse,
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text('Browse catalog'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              'Browse without logging in',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
