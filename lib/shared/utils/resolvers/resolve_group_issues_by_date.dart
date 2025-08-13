import 'package:afyakit/features/records/issues/models/issue_record.dart';

Map<int, Map<int, Map<int, List<IssueRecord>>>> resolveGroupIssuesByDate(
  List<IssueRecord> issues,
) {
  final Map<int, Map<int, Map<int, List<IssueRecord>>>> grouped = {};

  for (final issue in issues) {
    final date = issue.dateIssuedOrReceived ?? issue.dateRequested;

    final y = date.year;
    final m = date.month;
    final d = date.day;

    grouped.putIfAbsent(y, () => {});
    grouped[y]!.putIfAbsent(m, () => {});
    grouped[y]![m]!.putIfAbsent(d, () => []);
    grouped[y]![m]![d]!.add(issue);
  }

  return grouped;
}
