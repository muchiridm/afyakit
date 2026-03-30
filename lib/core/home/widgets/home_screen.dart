// lib/core/home/widgets/home_screen.dart

import 'package:afyakit/features/delivery_addresses/widgets/delivery_addresses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/widgets/components/home_header.dart';
import 'package:afyakit/core/home/widgets/member/member_latest_activity_panel.dart';
import 'package:afyakit/core/home/widgets/staff/staff_features_panel.dart';
import 'package:afyakit/core/home/widgets/staff/staff_latest_activity_panel.dart';

import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/retail/invoices/widgets/invoices_list_screen.dart';
import 'package:afyakit/features/retail/payments/zoho/widgets/payments_list_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quotes_list_screen.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';

import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.realEntry,
    required this.effectiveEntry,
    required this.user,
  });

  final EntryMode realEntry;
  final EntryMode effectiveEntry;

  /// In HomeShell we only build HomeScreen for non-guests,
  /// but keep nullable for safety/future reuse.
  final AuthUser? user;

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
        EntryMode.guest => const _GuestHomeBody(),
        EntryMode.member => _MemberHomeBody(user: user),
        EntryMode.staff => _StaffHomeBody(user: user),
      },
    );
  }
}

// ─────────────────────────────────────────────
// MEMBER HOME (REAL MEMBER MODE)
// If the toggle says Member, this is member mode.
// No "view-as" concept.
// Everything here must be "my account", keyed by uid/accountNumber.
// ─────────────────────────────────────────────
class _MemberHomeBody extends StatelessWidget {
  const _MemberHomeBody({required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final u = user;

    final greeting = (u == null) ? 'Member' : u.computedDisplayName;
    final memberId = (u?.accountNumber ?? '').trim();
    final showMemberId = memberId.isNotEmpty ? memberId : null;

    return _stack([
      HomeHeader(
        entry: EntryMode.member,
        greetingName: greeting,
        memberId: showMemberId,
        showDeliveryBanner: false,
        panelWidth: AppLayout.pageMaxW,
      ),

      const _MemberHouseholdInfoCard(),
      const _MemberQuickActions(),

      // If accountNumber is missing, fail gracefully (don’t look “blank”).
      if (u == null)
        const _MemberMissingUserHint()
      else if (memberId.isEmpty)
        const _MemberMissingAccountHint()
      else
        const MemberLatestActivityPanel(),

      const SizedBox(height: AppShape.gap12),
    ]);
  }
}

class _MemberQuickActions extends StatelessWidget {
  const _MemberQuickActions();

  void _showTodo(BuildContext context, String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label screen coming next.')));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppShape.gap10,
      runSpacing: AppShape.gap10,
      children: [
        _ActionChip(
          icon: Icons.grid_view_rounded,
          label: 'Catalog',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CatalogScreen())),
        ),
        _ActionChip(
          icon: Icons.people_alt_outlined,
          label: 'My Profiles',
          onTap: () => _showTodo(context, 'Patient profiles'),
        ),
        _ActionChip(
          icon: Icons.location_on_outlined,
          label: 'Delivery Addresses',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DeliveryAddressesScreen()),
          ),
        ),
        _ActionChip(
          icon: Icons.receipt_long_outlined,
          label: 'My Quotes',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const QuotesListScreen(scope: RetailDocScope.mine),
            ),
          ),
        ),
        _ActionChip(
          icon: Icons.receipt_outlined,
          label: 'My Invoices',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const InvoicesListScreen(scope: RetailDocScope.mine),
            ),
          ),
        ),
        _ActionChip(
          icon: Icons.payments_outlined,
          label: 'My Payments',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const PaymentsListScreen(scope: RetailDocScope.mine),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _MemberHouseholdInfoCard extends StatelessWidget {
  const _MemberHouseholdInfoCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.family_restroom_outlined, size: 20),
            const SizedBox(width: AppShape.gap10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage yourself and your dependents',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You will be able to save patient profiles for yourself, children, spouse, parents, and other dependents, plus multiple delivery addresses for prescriptions and orders.',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberMissingUserHint extends StatelessWidget {
  const _MemberMissingUserHint();

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.info_outline,
      title: 'Loading your account…',
      body:
          'Your member dashboard will appear once your profile is loaded. If it stays like this, refresh or log out and log in again.',
    );
  }
}

class _MemberMissingAccountHint extends StatelessWidget {
  const _MemberMissingAccountHint();

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.warning_amber_rounded,
      title: 'Member ID missing',
      body:
          'Your accountNumber is missing, so member activity can’t be loaded. This is usually a backend/profile issue. Fix: ensure your member profile has accountNumber (e.g. DP-000123).',
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: AppShape.gap10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: t.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STAFF HOME
// ─────────────────────────────────────────────
class _StaffHomeBody extends StatelessWidget {
  const _StaffHomeBody({required this.user});

  final AuthUser? user;

  static const double _twoColBreakpoint = 720;

  @override
  Widget build(BuildContext context) {
    final greeting = user?.computedDisplayName ?? 'Staff';

    return _stack([
      HomeHeader(
        entry: EntryMode.staff,
        greetingName: greeting,
        memberId: null,
        showDeliveryBanner: true,
        panelWidth: AppLayout.pageMaxW,
      ),
      LayoutBuilder(
        builder: (context, c) {
          final twoCol = c.maxWidth >= _twoColBreakpoint;

          const latest = StaffLatestActivityPanel();
          const features = StaffFeaturesPanel();

          if (!twoCol) return _stack([latest, features], gap: AppShape.gap12);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(child: features),
              SizedBox(width: AppShape.gap12),
              Expanded(child: latest),
            ],
          );
        },
      ),
      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap16);
  }
}

// ─────────────────────────────────────────────
// GUEST HOME (kept minimal)
// ─────────────────────────────────────────────
class _GuestHomeBody extends StatelessWidget {
  const _GuestHomeBody();

  @override
  Widget build(BuildContext context) {
    return _stack([
      HomeHeader(
        entry: EntryMode.guest,
        greetingName: 'Guest',
        memberId: null,
        showDeliveryBanner: false,
        panelWidth: AppLayout.pageMaxW,
      ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat with pharmacist (TODO)')),
          );
        },
      ),
      const SizedBox(height: AppShape.gap12),
    ]);
  }
}

// ─────────────────────────────────────────────
// Shared layout helper
// ─────────────────────────────────────────────
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
// Guest search hero
// ─────────────────────────────────────────────
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

  void _submit() => widget.onSearch(_c.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
