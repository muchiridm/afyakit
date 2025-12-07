import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/shared/widgets/screens/base_screen.dart';
import 'package:afyakit/shared/widgets/screens/screen_header.dart';

class GroupedRecordsScreen<T> extends StatelessWidget {
  final AsyncValue<List<T>> recordsAsync;
  final String title;
  final DateTime Function(T record) dateExtractor;
  final Widget Function(T record) recordTileBuilder;
  final double? maxContentWidth; // 👈 NEW

  const GroupedRecordsScreen({
    super.key,
    required this.recordsAsync,
    required this.title,
    required this.dateExtractor,
    required this.recordTileBuilder,
    this.maxContentWidth, // 👈 Optional
  });

  @override
  Widget build(BuildContext context) {
    return recordsAsync.when(
      loading: () => BaseScreen(
        scrollable: false,
        header: ScreenHeader(title),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => BaseScreen(
        scrollable: false,
        header: ScreenHeader(title),
        body: Center(child: Text('❌ Error loading records: $error')),
      ),
      data: (records) {
        if (records.isEmpty) {
          return BaseScreen(
            scrollable: false,
            header: ScreenHeader(title),
            body: const Center(
              child: Text(
                'No records found.',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
            ),
          );
        }

        final now = DateTime.now();
        final grouped = _groupByDate(records);

        final sortedYears = grouped.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key)); // descending

        return BaseScreen(
          scrollable: true,
          maxContentWidth: maxContentWidth, // 👈 Apply it
          header: ScreenHeader(title),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sortedYears.map((yearEntry) {
              final expandYear = yearEntry.key == now.year;
              return ExpansionTile(
                title: _sectionHeader('${yearEntry.key}'),
                initiallyExpanded: expandYear,
                children: _buildMonthTiles(
                  yearEntry.key,
                  yearEntry.value,
                  expandYear,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// Groups records by Year → Month → Day
  Map<int, Map<int, Map<int, List<T>>>> _groupByDate(List<T> records) {
    final map = <int, Map<int, Map<int, List<T>>>>{};

    for (final record in records) {
      final date = dateExtractor(record);
      final y = date.year, m = date.month, d = date.day;

      map[y] ??= {};
      map[y]![m] ??= {};
      map[y]![m]![d] ??= [];
      map[y]![m]![d]!.add(record);
    }

    return map;
  }

  /// Builds Month → Day tiles for a given year
  List<Widget> _buildMonthTiles(
    int year,
    Map<int, Map<int, List<T>>> months,
    bool expandYear,
  ) {
    final now = DateTime.now();

    final sortedMonths = months.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // descending

    return sortedMonths.map((monthEntry) {
      final month = monthEntry.key;
      final days = monthEntry.value;
      final expandMonth = expandYear && month == now.month;
      final label = DateFormat.MMMM().format(DateTime(year, month));

      return ExpansionTile(
        title: _subHeader(label),
        initiallyExpanded: expandMonth,
        children: _buildDayTiles(year, month, days),
      );
    }).toList();
  }

  /// Builds Day tiles for a given year and month
  List<Widget> _buildDayTiles(int year, int month, Map<int, List<T>> days) {
    final sortedDays = days.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // descending

    return sortedDays.map((dayEntry) {
      final day = dayEntry.key;
      final fullDate = DateTime(year, month, day);
      final label = DateFormat('EEE, d MMM').format(fullDate);
      final records = dayEntry.value;

      return ExpansionTile(
        title: _dayHeader(label),
        children: records.map(recordTileBuilder).toList(),
      );
    }).toList();
  }

  Widget _sectionHeader(String text) => Text(
    text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  );

  Widget _subHeader(String text) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  Widget _dayHeader(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold));
}
