import 'dart:convert';
import 'dart:io' show File;
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'web_download.dart'; // ✅ Conditionally exports web-only logic

class BackupService {
  static Future<void> backupCollection({
    required String collectionPath,
    String? outputFilePath,
    bool includeSubcollections = false,
  }) async {
    debugPrint('📦 Starting backup for $collectionPath');

    if (kIsWeb && includeSubcollections && collectionPath == 'stores') {
      return _backupStoresWithSubcollectionsWeb();
    }

    final collection = db.collection(collectionPath);
    final snapshot = await collection.get();

    final docs = await Future.wait(
      snapshot.docs.map((doc) async {
        final baseData = _normalizeFirestoreData(doc.data());

        if (includeSubcollections && !kIsWeb) {
          final subMap = await _fetchSubcollections(doc.reference);
          baseData.addAll(subMap);
        }

        return {'id': doc.id, 'data': baseData};
      }),
    );

    final output = {
      'collection': collectionPath,
      'count': docs.length,
      'docs': docs,
    };

    final prettyJson = const JsonEncoder.withIndent('  ').convert(output);
    final filename =
        '${collectionPath.replaceAll('/', '_')}_backup_${_timestamp()}.json';

    if (kIsWeb) {
      await downloadJsonInWeb(prettyJson, filename);
    } else {
      final savePath =
          outputFilePath ??
          '${(await getApplicationDocumentsDirectory()).path}/$filename';
      final file = File(savePath);
      await file.create(recursive: true);
      await file.writeAsString(prettyJson);
      debugPrint('✅ Backup saved to $savePath');
    }
  }

  static Future<void> _backupStoresWithSubcollectionsWeb() async {
    final storesSnap = await db.collection('stores').get();

    final docs = await Future.wait(
      storesSnap.docs.map((doc) async {
        final baseData = _normalizeFirestoreData(doc.data());

        try {
          final batchSnap = await db
              .collection('stores/${doc.id}/batches')
              .get();

          final batches = batchSnap.docs.map((b) {
            return {'id': b.id, 'data': _normalizeFirestoreData(b.data())};
          }).toList();

          baseData['batches'] = batches;
        } catch (e) {
          debugPrint('⚠️ Failed to fetch batches for store ${doc.id}: $e');
        }

        return {'id': doc.id, 'data': baseData};
      }),
    );

    final output = {'collection': 'stores', 'count': docs.length, 'docs': docs};

    final prettyJson = const JsonEncoder.withIndent('  ').convert(output);
    final filename = 'stores_backup_${_timestamp()}.json';

    await downloadJsonInWeb(prettyJson, filename);
  }

  static Future<Map<String, dynamic>> _fetchSubcollections(
    DocumentReference ref,
  ) async {
    final Map<String, dynamic> result = {};
    final subcollections = await (ref as dynamic).listCollections();

    for (final sub in subcollections) {
      final snap = await sub.get();
      result[sub.id] = snap.docs.map((doc) {
        return {'id': doc.id, 'data': _normalizeFirestoreData(doc.data())};
      }).toList();
    }

    return result;
  }

  static Map<String, dynamic> _normalizeFirestoreData(
    Map<String, dynamic> data,
  ) {
    return data.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toIso8601String());
      } else if (value is Map) {
        return MapEntry(
          key,
          _normalizeFirestoreData(Map<String, dynamic>.from(value)),
        );
      } else if (value is List) {
        return MapEntry(
          key,
          value.map((item) {
            if (item is Timestamp) return item.toDate().toIso8601String();
            if (item is Map) {
              return _normalizeFirestoreData(Map<String, dynamic>.from(item));
            }
            return item;
          }).toList(),
        );
      } else {
        return MapEntry(key, value);
      }
    });
  }

  static String _timestamp() {
    return DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
  }
}
