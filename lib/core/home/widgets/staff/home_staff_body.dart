// lib/core/home/widgets/staff/home_staff_body.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/widgets/user_badge.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/widgets/home_shared.dart';
import 'package:afyakit/core/home/widgets/staff/staff_features_panel.dart';
import 'package:afyakit/core/home/widgets/staff/staff_latest_activity_panel.dart';
import 'package:afyakit/core/home/widgets/staff/staff_primary_actions.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';

import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_service.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profile_form_dialog.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/retail/contacts/contacts_controller.dart';

import 'package:afyakit/shared/theme/app_shape.dart';

class HomeStaffBody extends ConsumerWidget {
  const HomeStaffBody({super.key, required this.user});

  final AuthUser? user;

  static const double _twoColBreakpoint = 900;

  void _openCatalog(BuildContext context, {String? q, bool autofocus = true}) {
    final query = (q ?? '').trim();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogScreen(
          initialQuery: query.isEmpty ? null : query,
          autofocusSearch: autofocus,
        ),
      ),
    );
  }

  void _openChatsInbox(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Staff chat inbox (TODO)')));
  }

  Future<void> _openAddPatientDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final input = await showDialog<PatientProfileUpsertInput>(
      context: context,
      builder: (_) =>
          const PatientProfileFormDialog(allowExplicitContactLink: true),
    );

    if (input == null || !context.mounted) return;

    try {
      final service = ref.read(patientProfilesServiceProvider);
      await service.create(input);

      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient profile created')));
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create patient profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantName = ref.watch(tenantDisplayNameProvider);

    final quickActions = StaffPrimaryActions(
      dense: true,
      onAddCustomer: () =>
          ref.read(contactsControllerProvider.notifier).openCreateFlow(context),
      onAddPatient: () => _openAddPatientDialog(context, ref),
      onRespondToChats: () => _openChatsInbox(context),
    );

    return homeVerticalStack([
      _StaffHomeTopBar(title: tenantName, trailing: quickActions),

      LayoutBuilder(
        builder: (context, c) {
          final twoCol = c.maxWidth >= _twoColBreakpoint;

          final mainColumn = _StaffMainColumn(
            onSearch: (q) => _openCatalog(context, q: q),
            onBrowseCatalog: () => _openCatalog(context, autofocus: true),
          );

          const featuresColumn = StaffFeaturesPanel();

          if (!twoCol) {
            return homeVerticalStack([
              mainColumn,
              featuresColumn,
            ], gap: AppShape.gap12);
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(flex: 1, child: featuresColumn),
              const SizedBox(width: AppShape.gap14),
              Expanded(flex: 1, child: mainColumn),
            ],
          );
        },
      ),

      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap14);
  }
}

class _StaffHomeTopBar extends StatelessWidget {
  const _StaffHomeTopBar({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  static const double _wideBp = 900;
  static const double _mediumBp = 620;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cleanTitle = title.trim().isEmpty ? 'AfyaKit' : title.trim();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth;

          if (width >= _wideBp) {
            return _StaffHomeTopBarShell(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: UserBadge(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 180),
                    child: _HeaderTitle(cleanTitle, style: t.titleMedium),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: _HeaderActionsScroller(child: trailing),
                    ),
                  ),
                ],
              ),
            );
          }

          if (width >= _mediumBp) {
            return _StaffHomeTopBarShell(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderTitle(cleanTitle, style: t.titleMedium),
                  const SizedBox(height: AppShape.gap10),
                  Row(
                    children: [
                      const UserBadge(),
                      const SizedBox(width: AppShape.gap12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _HeaderActionsScroller(child: trailing),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return _StaffHomeTopBarShell(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderTitle(cleanTitle, style: t.titleMedium),
                const SizedBox(height: AppShape.gap8),
                const UserBadge(),
                const SizedBox(height: AppShape.gap10),
                Center(child: _HeaderActionsScroller(child: trailing)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderActionsScroller extends StatelessWidget {
  const _HeaderActionsScroller({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    );
  }
}

class _StaffHomeTopBarShell extends StatelessWidget {
  const _StaffHomeTopBarShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: child,
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle(this.title, {required this.style});

  final String title;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: style?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.2),
    );
  }
}

class _StaffMainColumn extends StatelessWidget {
  const _StaffMainColumn({
    required this.onSearch,
    required this.onBrowseCatalog,
  });

  final void Function(String query) onSearch;
  final VoidCallback onBrowseCatalog;

  @override
  Widget build(BuildContext context) {
    return homeVerticalStack([
      const _QuietStaffLatestActivity(),

      _StaffSection(
        title: 'Search',
        icon: Icons.search_rounded,
        child: HomeCatalogSearchHero(
          autofocus: false,
          hintText: 'Search medicines, brands, patients, customers…',
          footerText: 'Search the catalog while serving a customer',
          onSearch: onSearch,
          onBrowse: onBrowseCatalog,
        ),
      ),
    ], gap: AppShape.gap14);
  }
}

class _StaffSection extends StatelessWidget {
  const _StaffSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: AppShape.gap8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppShape.gap8),
        child,
      ],
    );
  }
}

class _QuietStaffLatestActivity extends StatelessWidget {
  const _QuietStaffLatestActivity();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: 0.84,
      child: Material(
        elevation: 0,
        color: scheme.surface.withOpacity(0.64),
        borderRadius: BorderRadius.circular(14),
        child: const StaffLatestActivityPanel(),
      ),
    );
  }
}
