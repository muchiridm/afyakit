import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/current_user_providers.dart';
import 'package:collection/collection.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/core/records/issues/controllers/controllers/issue_action_controller.dart';
import 'package:afyakit/core/records/issues/models/enums/issue_status_enum.dart';
import 'package:afyakit/core/records/issues/models/enums/issue_status_x.dart';
import 'package:afyakit/core/records/issues/models/issue_record.dart';
import 'package:afyakit/core/records/issues/providers/issues_stream_provider.dart';
import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';

import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/detail_record_screen.dart';
import 'package:afyakit/shared/utils/format/format_date.dart';

class IssueDetailsScreen extends ConsumerWidget {
  final String issueId;
  const IssueDetailsScreen({super.key, required this.issueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final asyncIssues = ref.watch(hydratedIssuesStreamProvider(tenantId));
    final asyncUser = ref.watch(currentUserProvider);

    final asyncStores = ref.watch(
      inventoryLocationProvider(InventoryLocationType.store),
    );
    final asyncDispensaries = ref.watch(
      inventoryLocationProvider(InventoryLocationType.dispensary),
    );

    final controller = ref.watch(issueActionControllerProvider);

    return asyncIssues.when(
      loading: _buildLoading,
      error: (e, _) => _buildError('issue', e),
      data: (issues) {
        final issue = issues.firstWhereOrNull((i) => i.id == issueId);
        if (issue == null) return _buildNotFound('Issue');

        // 🔹 Resolve "Requested By" with the shared provider (uid → name/email)
        final requestedBy = ref
            .watch(userDisplayProvider(issue.requestedByUid))
            .maybeWhen(data: (v) => v, orElse: () => issue.requestedByUid);

        return asyncUser.when(
          loading: _buildLoading,
          error: (e, _) => _buildError('user', e),
          data: (user) {
            if (user == null || controller == null) {
              return _buildNotFound('User or Controller');
            }

            final stores =
                asyncStores.asData?.value ?? const <InventoryLocation>[];
            final dispensaries =
                asyncDispensaries.asData?.value ?? const <InventoryLocation>[];

            final fromStoreName = resolveLocationName(
              issue.fromStore,
              stores,
              dispensaries,
            );
            final toStoreName = resolveLocationName(
              issue.toStore,
              stores,
              dispensaries,
            );

            return _buildScreen(
              context,
              issue,
              user,
              requestedBy, // ← pass resolved display string
              controller,
              asyncStores, // keep passing AsyncValue for actions
              fromStoreName: fromStoreName,
              toStoreName: toStoreName,
            );
          },
        );
      },
    );
  }

  Widget _buildLoading() => const BaseScreen(
    scrollable: false,
    body: Center(child: CircularProgressIndicator()),
  );

  Widget _buildError(String source, Object error) =>
      BaseScreen(body: Center(child: Text('❌ Failed to load $source: $error')));

  Widget _buildNotFound(String entity) =>
      BaseScreen(body: Center(child: Text('⚠️ $entity not found.')));

  Widget _buildScreen(
    BuildContext context,
    IssueRecord issue,
    AuthUser user,
    String requestedByDisplay, // ← simplified
    IssueActionController controller,
    AsyncValue<List<InventoryLocation>> allStores, {
    required String fromStoreName,
    required String toStoreName,
  }) {
    return DetailRecordScreen(
      maxContentWidth: 1000,
      header: AppBar(title: const Text('Issue Request Details')),
      contentSections: [
        _buildSummary(issue, fromStoreName, toStoreName),
        const Divider(height: 32),
        ..._buildEntries(issue),
        const Divider(height: 32),
        _buildMeta(issue, requestedByDisplay),
      ],
      actionButtons: _buildActionButtons(
        context,
        issue,
        user,
        controller,
        allStores,
      ),
    );
  }

  Widget _buildSummary(IssueRecord issue, String fromStore, String toStore) {
    return Wrap(
      spacing: 32,
      runSpacing: 12,
      children: [
        _info(
          'Status',
          IssueStatusX.fromString(issue.status).label,
          color: getIssueStatusColor(issue.statusEnum),
        ),
        _info('Note', issue.note),
        _info('From Store', fromStore),
        _info('To Store', toStore),
      ],
    );
  }

  List<Widget> _buildEntries(IssueRecord issue) {
    return issue.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📦 ${entry.itemName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 20,
                  runSpacing: 4,
                  children: [
                    _info('Type', entry.itemType.label),
                    _info('Group', entry.itemGroup),
                    _info('Strength', entry.strength),
                    _info('Formulation', entry.formulation),
                    _info('Size', entry.size),
                    _info('Pack Size', entry.packSize),
                    _info('Batch ID', entry.batchId),
                    _info('Quantity', '${entry.quantity}'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildMeta(IssueRecord issue, String requestedByDisplay) {
    return Wrap(
      spacing: 32,
      runSpacing: 12,
      children: [
        _info('Requested By', requestedByDisplay),
        _info('Requested At', formatDate(issue.dateRequested)),
        if (issue.dateApproved != null)
          _info('Approved At', formatDate(issue.dateApproved!)),
        if (issue.actionedByName != null)
          _info('Actioned By', issue.actionedByName!),
        if (issue.actionedByRole != null) _info('Role', issue.actionedByRole!),
        if (issue.dateIssuedOrReceived != null)
          _info('Issued At', formatDate(issue.dateIssuedOrReceived!)),
      ],
    );
  }

  List<Widget> _buildActionButtons(
    BuildContext context,
    IssueRecord issue,
    AuthUser user,
    IssueActionController controller,
    AsyncValue<List<InventoryLocation>> allStores,
  ) {
    if (allStores is! AsyncData) {
      debugPrint(
        '[Buttons] Stores not ready yet for issue=${issue.id} '
        '(state=${allStores.runtimeType})',
      );
      return [];
    }

    final stores = allStores.value ?? const <InventoryLocation>[];
    final actions = controller.getAvailableActions(
      user: user,
      record: issue,
      allStores: stores,
    );

    debugPrint(
      '[Buttons] issue=${issue.id} '
      'status=${issue.status} from=${issue.fromStore} to=${issue.toStore} '
      'user=${user.uid} role=${user.role.name} '
      'stores=${stores.length} '
      '→ actions=[${actions.map((a) => a.label).join(', ')}]',
    );

    if (actions.isEmpty) {
      debugPrint('[Buttons] No available actions for issue=${issue.id}');
    }

    return actions.map((btn) {
      return ElevatedButton.icon(
        onPressed: () async {
          debugPrint('[Buttons] TAP "${btn.label}" issue=${issue.id}');
          try {
            btn.onPressed(context); // ← await so errors surface
            debugPrint('[Buttons] DONE "${btn.label}" issue=${issue.id}');
          } catch (e, st) {
            debugPrint(
              '[Buttons][ERR] "${btn.label}" issue=${issue.id}: $e\n$st',
            );
            // Optional: show a quick toast/snack for the user
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Action "${btn.label}" failed: $e')),
            );
          }
        },
        icon: Icon(btn.icon, color: Colors.white),
        label: Text(
          btn.label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: btn.color,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      );
    }).toList();
  }

  Widget _info(String label, String? value, {Color? color}) {
    final display = (value?.trim().isNotEmpty ?? false) ? value!.trim() : '-';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Flexible(
          child: Text(
            display,
            style: TextStyle(color: color, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
