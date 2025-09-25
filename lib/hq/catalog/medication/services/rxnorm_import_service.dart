import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';

final rxnormImportServiceProvider = Provider<RxnormImportService>(
  (ref) => RxnormImportService(functions),
);

class RxnormImportService {
  RxnormImportService(this._fn);
  final FirebaseFunctions _fn;

  Future<String> importByName(String name) async {
    try {
      final res = await _fn
          .httpsCallable('importRxnormByName')
          .call<Map<String, dynamic>>({'name': name.trim()});
      final data = (res.data as Map).cast<String, dynamic>();
      return data['id'] as String;
    } on FirebaseFunctionsException catch (e) {
      // surface callable error message
      throw '${e.code}: ${e.message ?? 'Import by name failed'}';
    }
  }

  Future<String> importByRxcui(String rxcui) async {
    try {
      final res = await _fn
          .httpsCallable('importRxnormByRxcui')
          .call<Map<String, dynamic>>({'rxcui': rxcui.trim()});
      final data = (res.data as Map).cast<String, dynamic>();
      return data['id'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw '${e.code}: ${e.message ?? 'Import by RXCUI failed'}';
    }
  }
}
