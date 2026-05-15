// lib/core/home/widgets/staff/staff_features_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/models/staff_feature_def.dart';
import 'package:afyakit/core/home/registry/home_registry.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';

class StaffFeaturesPanel extends ConsumerWidget {
  const StaffFeaturesPanel({super.key});

  static const double _twoColBreakpoint = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final features = _orderedFeatures(
      HomeRegistry.featureTiles(ref, user, scope: HomeScope.staff),
    );

    if (features.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return AppCard(
      title: 'Features',
      icon: Icons.grid_view_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Features you are subscribed to:',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: AppShape.gap12),
          LayoutBuilder(
            builder: (context, c) {
              final twoCol = c.maxWidth >= _twoColBreakpoint;

              if (!twoCol) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < features.length; i++) ...[
                      _FeatureTile(
                        feature: features[i],
                        user: user,
                        scope: HomeScope.staff,
                      ),
                      if (i != features.length - 1)
                        const SizedBox(height: AppShape.gap12),
                    ],
                  ],
                );
              }

              final tileW = (c.maxWidth - AppShape.gap12) / 2;

              return Wrap(
                spacing: AppShape.gap12,
                runSpacing: AppShape.gap12,
                children: [
                  for (final f in features)
                    SizedBox(
                      width: tileW,
                      child: _FeatureTile(
                        feature: f,
                        user: user,
                        scope: HomeScope.staff,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static List<StaffFeatureDef> _orderedFeatures(
    List<StaffFeatureDef> features,
  ) {
    final ordered = [...features];

    ordered.sort((a, b) {
      final byGroup = _featureGroupRank(a).compareTo(_featureGroupRank(b));
      if (byGroup != 0) return byGroup;

      final byLabel = a.label.toLowerCase().compareTo(b.label.toLowerCase());
      if (byLabel != 0) return byLabel;

      return _featureKeyText(a).compareTo(_featureKeyText(b));
    });

    return ordered;
  }

  static int _featureGroupRank(StaffFeatureDef feature) {
    final haystack = [
      _featureKeyText(feature),
      feature.label,
      feature.description ?? '',
    ].join(' ').toLowerCase();

    // 1. Clinical first.
    if (_containsAny(haystack, const [
      'clinical',
      'patient',
      'patients',
      'prescription',
      'prescriptions',
      'doctor',
      'consult',
    ])) {
      return 10;
    }

    // 2. Messaging / contacts.
    // Contacts/customers live here, not Retail.
    if (_containsAny(haystack, const [
      'messaging',
      'message',
      'messages',
      'chat',
      'chats',
      'conversation',
      'conversations',
      'contact',
      'contacts',
      'customer',
      'customers',
      'whatsapp',
      'sms',
      'email',
      'inbox',
    ])) {
      return 20;
    }

    // 3. Retail / sales / commerce.
    if (_containsAny(haystack, const [
      'retail',
      'catalog',
      'sales',
      'quote',
      'quotes',
      'invoice',
      'invoices',
      'payment',
      'payments',
      'delivery',
      'address',
      'addresses',
      'order',
      'orders',
      'cart',
      'checkout',
    ])) {
      return 30;
    }

    // 4. Insurance.
    if (_containsAny(haystack, const [
      'insurance',
      'claim',
      'claims',
      'membership',
      'memberships',
      'payer',
      'payers',
      'scheme',
      'schemes',
      'policy',
      'policies',
    ])) {
      return 40;
    }

    // 5. Inventory / stock / stores.
    if (_containsAny(haystack, const [
      'inventory',
      'stock',
      'store',
      'stores',
      'batch',
      'batches',
      'issue',
      'issues',
      'delivery note',
      'reorder',
      'supplier',
      'suppliers',
      'medication',
      'consumable',
      'equipment',
    ])) {
      return 50;
    }

    // 6. Admin / HQ / users / settings.
    if (_containsAny(haystack, const [
      'admin',
      'hq',
      'user',
      'users',
      'tenant',
      'tenants',
      'setting',
      'settings',
      'profile',
      'profiles',
      'role',
      'roles',
      'permission',
      'permissions',
    ])) {
      return 60;
    }

    // Everything else last.
    return 90;
  }

  static bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) return true;
    }

    return false;
  }

  static String _featureKeyText(StaffFeatureDef feature) {
    return feature.featureKey.toString().trim().toLowerCase();
  }
}

class _FeatureTile extends ConsumerWidget {
  const _FeatureTile({
    required this.feature,
    required this.user,
    required this.scope,
  });

  final StaffFeatureDef feature;
  final AuthUser user;
  final HomeScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = HomeRegistry.actionsFor(
      ref,
      user,
      feature.featureKey,
      scope: scope,
    );

    return SizedBox(
      width: double.infinity,
      child: AppTile(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FeatureHeader(feature: feature),
            _FeatureDesc(feature: feature),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppShape.gap10),
              Wrap(
                spacing: AppShape.gap10,
                runSpacing: AppShape.gap10,
                children: actions.map((a) => _ActionChip(action: a)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureHeader extends StatelessWidget {
  const _FeatureHeader({required this.feature});

  final StaffFeatureDef feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(feature.icon, size: 20),
        const SizedBox(width: AppShape.gap10),
        Expanded(
          child: Text(
            feature.label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(Icons.chevron_right, size: 20),
      ],
    );
  }
}

class _FeatureDesc extends StatelessWidget {
  const _FeatureDesc({required this.feature});

  final StaffFeatureDef feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = (feature.description ?? '').trim();
    if (d.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        d,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.action});

  final StaffFeatureDef action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        icon: Icon(action.icon, size: 18),
        label: Text(action.label),
        onPressed: () {
          final dest = action.destination;
          if (dest == null) {
            SnackService.showError('🚧 ${action.label} is not wired yet.');
            return;
          }

          Navigator.of(context).push(MaterialPageRoute(builder: dest));
        },
      ),
    );
  }
}
