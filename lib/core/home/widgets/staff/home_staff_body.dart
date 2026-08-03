// lib/core/home/widgets/staff/home_staff_body.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/activities/shared/staff_activity_history_screen.dart';
import 'package:afyakit/core/home/activities/shared/staff_latest_activity_panel.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_header.dart';
import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_shared.dart';
import 'package:afyakit/core/home/widgets/staff/staff_features_panel.dart';

import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';

import 'package:afyakit/shared/theme/app_shape.dart';

class HomeStaffBody extends StatelessWidget {
  const HomeStaffBody({super.key, required this.user});

  final AuthUser? user;

  void _openCatalog(BuildContext context, {String? q, bool autofocus = true}) {
    final String query = (q ?? '').trim();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogScreen(
          initialQuery: query.isEmpty ? null : query,
          autofocusSearch: autofocus,
          entry: EntryMode.staff,
          user: user,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return homeVerticalStack([
      const HomeHeader(
        entry: EntryMode.staff,
        showDeliveryBanner: false,
        showHomeButton: false,
      ),
      HomeDashboardTwoColumnLayout(
        leading: const StaffFeaturesPanel(),
        trailing: _StaffMainColumn(
          onSearch: (query) => _openCatalog(context, q: query),
          onBrowseCatalog: () => _openCatalog(context, autofocus: true),
        ),
      ),
      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap14);
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
      HomeSection(
        title: 'Search',
        icon: Icons.search_rounded,
        child: HomeCatalogSearchHero(
          autofocus: false,
          hintText: 'Search medicines, brands, patients or customers',
          footerText: 'Search the catalogue',
          onSearch: onSearch,
          onBrowse: onBrowseCatalog,
        ),
      ),
      QuietHomePanel(
        child: StaffLatestActivityPanel(
          onTitleTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const StaffActivityHistoryScreen(),
            ),
          ),
        ),
      ),
    ], gap: AppShape.gap14);
  }
}
