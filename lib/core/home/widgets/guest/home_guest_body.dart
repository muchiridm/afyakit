// lib/core/home/widgets/guest/home_guest_body.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/widgets/shared/dashboard/home_header.dart';
import 'package:afyakit/core/home/widgets/shared/dashboard/home_shared.dart';

import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';

import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

class HomeGuestBody extends StatelessWidget {
  const HomeGuestBody({super.key});

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

  void _chatWithPharmacist(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat with pharmacist (TODO)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return homeVerticalStack([
      HomeHeader(
        entry: EntryMode.guest,
        greetingName: 'Guest',
        memberId: null,
        showDeliveryBanner: false,
        panelWidth: AppLayout.contentMaxWidth,
      ),
      HomeCatalogSearchHero(
        autofocus: true,
        footerText: 'Browse without logging in',
        onSearch: (q) => _openCatalog(context, q: q),
        onBrowse: () => _openCatalog(context, autofocus: true),
        onSecondaryTap: () => _chatWithPharmacist(context),
        secondaryLabel: 'Chat pharmacist',
        secondaryIcon: Icons.chat_bubble_outline_rounded,
      ),
      const SizedBox(height: AppShape.gap12),
    ]);
  }
}
