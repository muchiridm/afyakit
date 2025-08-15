import 'package:collection/collection.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:afyakit/users/controllers/user_profile_editor_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/features/records/issues/controllers/controllers/issue_action_controller.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_status_enum.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_status_x.dart';
import 'package:afyakit/features/records/issues/models/issue_record.dart';
import 'package:afyakit/shared/providers/stock/issues_stream_provider.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/users/providers/combined_user_provider.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/detail_record_screen.dart';
import 'package:afyakit/shared/utils/format/format_date.dart';
import 'package:afyakit/users/models/combined_user_model.dart';

class IssueDetailsScreen extends ConsumerWidget {
  final String issueId;
  const IssueDetailsScreen({super.key, required this.issueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final asyncIssues = ref.watch(hydratedIssuesStreamProvider(tenantId));
    final asyncUser = ref.watch(combinedUserProvider);

    // 👇 watch both stores and dispensaries
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

        final requestedByUser = ref.watch(
          combinedUserByIdProvider(issue.requestedByUid),
        );

        return asyncUser.when(
          loading: _buildLoading,
          error: (e, _) => _buildError('user', e),
          data: (user) {
            if (user == null || controller == null) {
              return _buildNotFound('User or Controller');
            }

            // 👇 resolve names using shared util with both lists
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
              requestedByUser?.displayName,
              controller,
              asyncStores, // keep passing stores AsyncValue for actions
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
    CombinedUser user,
    String? requestedByName,
    IssueActionController controller,
    AsyncValue<List<InventoryLocation>> allStores, {
    required String fromStoreName,
    required String toStoreName,
  }) {
    return DetailRecordScreen(
      maxContentWidth: 1000,
      header: AppBar(title: const Text('Issue Request Details')),
      contentSections: [
        _buildSummary(
          issue,
          fromStoreName,
          toStoreName,
        ), // 👈 already takes names
        const Divider(height: 32),
        ..._buildEntries(issue),
        const Divider(height: 32),
        _buildMeta(issue, requestedByName),
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
    return issue.entries
        .map(
          (entry) => Padding(
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
          ),
        )
        .toList();
  }

  Widget _buildMeta(IssueRecord issue, String? requestedByName) {
    return Wrap(
      spacing: 32,
      runSpacing: 12,
      children: [
        _info('Requested By', requestedByName ?? issue.requestedByUid),
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
    CombinedUser user,
    IssueActionController controller,
    AsyncValue<List<InventoryLocation>> allStores,
  ) {
    if (allStores is! AsyncData) return [];

    final actions = controller.getAvailableActions(
      user: user,
      record: issue,
      allStores: allStores.value ?? [],
    );

    return actions
        .map(
          (btn) => ElevatedButton.icon(
            onPressed: () => btn.onPressed(context),
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
          ),
        )
        .toList();
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
