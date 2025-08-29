import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:afyakit/core/records/issues/models/issue_record.dart';
import 'package:afyakit/core/records/issues/screens/issue_details_screen.dart';
import 'package:afyakit/shared/utils/format/format_date.dart';
import 'package:afyakit/core/records/issues/models/enums/issue_status_enum.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:flutter/material.dart';

class IssueRecordTile extends StatelessWidget {
  final IssueRecord issue;
  final List<InventoryLocation> stores;
  final List<InventoryLocation> dispensaries;
  final bool compact;

  const IssueRecordTile({
    super.key,
    required this.issue,
    required this.stores,
    required this.dispensaries,
    this.compact = false,
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
    final to = resolveLocationName(issue.toStore, [
      ...stores,
      ...dispensaries,
    ], []);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        // keep it tight, but allow enough vertical room
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        title: _buildTitle(itemNames),
        subtitle: _buildSubtitle(itemCount, totalQty, from, to),
        trailing: _buildTrailing(color, timeStr),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IssueDetailsScreen(issueId: issue.id),
          ),
        ),
      ),
    );
  }

  // ── pieces ──────────────────────────────────────────────────────────

  Widget _buildTitle(String itemNames) {
    return Text(itemNames, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _buildSubtitle(int itemCount, int totalQty, String from, String to) {
    // Column that **shrinks** to fit the tile’s height → no overflow
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Column(
        mainAxisSize: MainAxisSize.min, // <- important
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items: $itemCount • Qty: $totalQty',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!compact)
            Text(
              'From: $from → $to',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailing(Color color, String timeStr) {
    // Wrap in FittedBox so, on narrow tiles, it scales down instead of overflowing
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Column(
        mainAxisSize: MainAxisSize.min, // <- important
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timeStr, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 4),
          Container(
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
    );
  }
}
