import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

import '../models/native_contact.dart';

final nativeContactsServiceProvider = FutureProvider<NativeContactsService>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final client = await ref.watch(afyakitClientFutureProvider.future);
  return NativeContactsService(client, AfyaKitRoutes(tenantId));
});

class NativeContactsService {
  const NativeContactsService(this.api, this.routes);

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  Map<String, dynamic> _object(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Unexpected contact API response');
  }

  Future<List<NativeContact>> list({int page = 1, int perPage = 50}) async {
    final res = await api.getUri<Object?>(
      routes.recordsNativeContactsList(page: page, perPage: perPage),
    );
    final items = _object(res.data)['contacts'];
    if (items is! List) throw const FormatException('Missing contacts array');
    return items.map((item) => NativeContact.fromJson(_object(item))).toList();
  }

  Future<NativeContact> get(String id) async {
    final res = await api.getUri<Object?>(routes.recordsNativeContactGet(id));
    return NativeContact.fromJson(_object(_object(res.data)['contact']));
  }

  Future<NativeContact> create(Map<String, Object?> body) async {
    final res = await api.postUri<Object?>(routes.recordsNativeContactCreate(), data: body);
    return NativeContact.fromJson(_object(_object(res.data)['contact']));
  }

  Future<NativeContact> update(String id, Map<String, Object?> body) async {
    final res = await api.putUri<Object?>(routes.recordsNativeContactUpdate(id), data: body);
    return NativeContact.fromJson(_object(_object(res.data)['contact']));
  }

  Future<String> allocateAccountNumber(String id) async {
    final res = await api.postUri<Object?>(
      routes.recordsNativeContactAllocateAccountNumber(id),
      data: <String, Object?>{},
    );
    final account = _object(res.data)['account_number'];
    if (account is! String || account.trim().isEmpty) {
      throw const FormatException('Missing generated account_number');
    }
    return account;
  }

  Future<void> removeFromApp(String id) async {
    await api.deleteUri<Object?>(routes.recordsNativeContactRemoveFromApp(id));
  }
}
