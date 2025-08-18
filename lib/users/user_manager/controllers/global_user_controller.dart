import 'dart:async';
import 'package:afyakit/users/user_manager/models/global_user_model.dart';
import 'package:afyakit/users/user_manager/services/global_user_service.dart';
import 'package:flutter/foundation.dart';

class GlobalUserController extends ChangeNotifier {
  GlobalUserController(this._svc);

  final GlobalUserService _svc;

  String _tenantFilter = ''; // '', 'afyakit', 'danabtmc', 'dawapap'
  String _search = '';
  int _limit = 50;

  String get tenantFilter => _tenantFilter;
  String get search => _search;
  int get limit => _limit;

  set tenantFilter(String v) {
    if (_tenantFilter == v) return;
    _tenantFilter = v;
    notifyListeners();
  }

  set search(String v) {
    if (_search == v) return;
    _search = v;
    notifyListeners();
  }

  set limit(int v) {
    if (_limit == v) return;
    _limit = v;
    notifyListeners();
  }

  Stream<List<GlobalUser>> get stream => _svc.usersStream(
    tenantId: _tenantFilter.isEmpty ? null : _tenantFilter,
    search: _search,
    limit: _limit,
  );

  Future<Map<String, Map<String, Object?>>> memberships(String uid) =>
      _svc.fetchMemberships(uid);
}
