import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/features/records/issues/models/issue_record.dart';
import 'package:afyakit/features/records/issues/screens/issue_details_screen.dart';
import 'package:afyakit/shared/utils/format/format_date.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_status_enum.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:flutter/material.dart';

class IssueRecordTile extends StatelessWidget {
  final IssueRecord issue;
  final List<InventoryLocation> stores;
  final List<InventoryLocation> dispensaries;
  final bool compact; // 🆕 optional compact mode

  const IssueRecordTile({
    super.key,
    required this.issue,
    required this.stores,
    required this.dispensaries,
    this.compact = false, // default to false
  });

  @override
  Widget build(BuildContext context) {
    final color = getIssueStatusColor(issue.statusEnum);
    final date = issue.dateIssuedOrReceived ?? issue.dateRequested;
    final timeStr = formatDate(date);

    final itemNames = issue.entries.map((e) => e.itemName).toSet().join(', ');
    final itemCount = issue.entries.length;
    final totalQty = issue.entries.fold<int>(0, (sum, e) => sum + e.quantity);

    final from = resolveLocationName(issue.fromStore, stores, []);
    final to = resolveLocationName(issue.toStore, stores + dispensaries, []);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(Icons.outbox, size: 16, color: color),
        ),
        title: Text(itemNames, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Items: $itemCount • Qty: $totalQty'),
              Text(
                'From: $from → $to',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(timeStr, style: const TextStyle(fontSize: 11)),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                issue.status.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IssueDetailsScreen(issueId: issue.id),
            ),
          );
        },
      ),
    );
  }
}
