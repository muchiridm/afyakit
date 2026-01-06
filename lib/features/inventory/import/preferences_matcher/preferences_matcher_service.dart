// lib/core/import/preferences_matcher/preferences_matcher_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import 'package:afyakit/features/inventory/import/preferences_matcher/models/field_match_model.dart';
import 'package:afyakit/features/inventory/import/preferences_matcher/models/prefs_match_model.dart';
import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/features/inventory/preferences/utils/item_preference_field.dart';
import 'package:afyakit/features/inventory/preferences/item_preferences_service.dart';

// Importer ImportType so the screen can call introspectFromBytes(...)
import 'package:afyakit/features/inventory/import/importer/models/import_type_x.dart'
    as importer;

/// Which preference fields we reconcile per item type.
List<ItemPreferenceField> fieldsFor(ItemType type) {
  switch (type) {
    case ItemType.medication:
      return const [
        ItemPreferenceField.group,
        ItemPreferenceField.formulation,
        ItemPreferenceField.route,
      ];
    case ItemType.consumable:
      return const [
        ItemPreferenceField.group,
        ItemPreferenceField.package,
        ItemPreferenceField.unit,
      ];
    case ItemType.equipment:
      return const [ItemPreferenceField.group];
    case ItemType.unknown:
      return const [];
  }
}

/// Normalizer used when guessing matches and header IDs.
String _norm(String s) => s.trim().toLowerCase();
String _id(String s) => _norm(s).replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Header aliases per field (accept camelCase, snake_case, spaced headers, etc.)
Map<ItemPreferenceField, List<String>> _headerAliases(ItemType type) {
  // Baseline aliases for all types
  final base = <ItemPreferenceField, List<String>>{
    ItemPreferenceField.group: const [
      'group',
      'itemGroup',
      'item_group',
      'category',
      'grp',
    ],
  };

  switch (type) {
    case ItemType.medication:
      return {
        ...base,
        ItemPreferenceField.formulation: const [
          'formulation',
          'dosageForm',
          'dosage_form',
          'doseForm',
          'form',
        ],
        ItemPreferenceField.route: const [
          'route',
          'routeOfAdministration',
          'route_of_administration',
          'administrationRoute',
          'adminRoute',
        ],
      };
    case ItemType.consumable:
      return {
        ...base,
        ItemPreferenceField.package: const [
          'package',
          'pack',
          'packaging',
          'packType',
        ],
        ItemPreferenceField.unit: const [
          'unit',
          'uom',
          'unitOfMeasure',
          'unit_of_measure',
        ],
      };
    case ItemType.equipment:
      return base;
    case ItemType.unknown:
      return const {};
  }
}

class PreferencesMatcherService {
  PreferencesMatcherService(this._prefs);
  final ItemPreferenceService _prefs;

  // ───────────────────────────────────────────────────────────────
  // Introspect the file and extract distinct values per field.
  //
  // We prefer camelCase headers, but accept snake_case/spaces/etc. via _id().
  // This returns only the fields relevant to the given ItemType.
  Future<Map<ItemPreferenceField, Iterable<String>>> introspectFromBytes({
    required importer.ImportType type,
    required String filename,
    required Uint8List bytes,
  }) async {
    final itemType = type.toItemType();
    final wantedFields = fieldsFor(itemType);
    if (wantedFields.isEmpty) return const {};

    final aliases = _headerAliases(
      itemType,
    ).map((k, v) => MapEntry(k, v.map(_id).toList()));

    // Parse rows (first row = headers). Each row is a List<String?>.
    final rows = await _readTable(filename, bytes);
    if (rows.isEmpty) return const {};

    final headerRow = rows.first.map((e) => (e ?? '').toString()).toList();
    final headerIds = headerRow.map(_id).toList();

    // Map field -> column index (if found)
    final columnIndex = <ItemPreferenceField, int?>{};
    for (final f in wantedFields) {
      final candidates = aliases[f] ?? const <String>[];
      int? idx;
      for (var i = 0; i < headerIds.length; i++) {
        if (candidates.contains(headerIds[i])) {
          idx = i;
          break;
        }
      }
      columnIndex[f] = idx; // can be null (not found)
    }

    // Collect distinct values per found column.
    final result = <ItemPreferenceField, Iterable<String>>{};
    for (final f in wantedFields) {
      final idx = columnIndex[f];
      if (idx == null) {
        result[f] = const <String>[];
        continue;
      }
      final set = <String>{};
      // Skip header row (start from 1)
      for (var r = 1; r < rows.length; r++) {
        final cell = (idx < (rows[r].length)) ? rows[r][idx] : null;
        final v = (cell ?? '').toString().trim();
        if (v.isNotEmpty) set.add(v);
      }
      result[f] = set;
    }

    return result;
  }

  // Read a 2D table (first row = headers) from CSV/XLS/XLSX.
  Future<List<List<Object?>>> _readTable(
    String filename,
    Uint8List bytes,
  ) async {
    final ext = filename.split('.').last.toLowerCase();

    if (ext == 'csv') {
      final content = utf8.decode(bytes, allowMalformed: true);
      final csv = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(content);
      // Ensure List<List<Object?>> shape
      return csv.map((row) => row.map((c) => c).toList()).toList();
    }

    // xls / xlsx via excel
    if (ext == 'xls' || ext == 'xlsx') {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) return <List<List<Object?>>>[];
      // Pick first visible sheet
      final sheet = excel.tables.values.first;
      final rows = <List<Object?>>[];
      for (final row in sheet.rows) {
        rows.add(row.map((d) => d?.value).toList());
      }
      return rows;
    }

    // Unknown: try CSV fallback
    final content = utf8.decode(bytes, allowMalformed: true);
    final csv = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content);
    return csv.map((row) => row.map((c) => c).toList()).toList();
  }

  // ───────────────────────────────────────────────────────────────
  // Build an initial model with guesses based on case-insensitive equality.
  Future<PrefsMatchModel> build(
    ItemType type,
    Map<ItemPreferenceField, Iterable<String>> incomingByField,
  ) async {
    final fields = fieldsFor(type);
    final map = <ItemPreferenceField, FieldMatchModel>{};

    for (final f in fields) {
      // 1) existing, sorted
      final existing = await _prefs.fetchValues(type, f);
      existing.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      // 2) incoming: trim + dedupe + drop empties
      final Iterable<String> source = incomingByField[f] ?? const <String>[];
      final set = <String>{for (final s in source) s.trim()}
        ..removeWhere((s) => s.isEmpty);
      final incoming = set.toList();

      // 3) prefill selections by normalized equality
      final selections = <String, String>{};
      for (final raw in incoming) {
        final guess = existing.firstWhere(
          (e) => _norm(e) == _norm(raw),
          orElse: () => '',
        );
        if (guess.isNotEmpty) selections[raw] = guess;
      }

      map[f] = FieldMatchModel(
        field: f,
        incoming: incoming,
        existing: existing,
        selections: selections,
      );
    }

    return PrefsMatchModel(type, map);
  }

  /// Create a new canonical preference value, return updated `existing` (sorted).
  Future<List<String>> createPreferenceValue({
    required ItemType type,
    required ItemPreferenceField field,
    required String value,
  }) async {
    await _prefs.addValue(type, field, value);
    final updated = await _prefs.fetchValues(type, field);
    updated.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return updated;
  }
}
