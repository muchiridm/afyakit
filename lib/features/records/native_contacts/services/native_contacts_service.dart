import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

import '../models/native_contact.dart';

final nativeContactsServiceProvider = FutureProvider<NativeContactsService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final client = await ref.watch(afyakitClientFutureProvider.future);

  return NativeContactsService(client, AfyaKitRoutes(tenantId));
});

class NativeContactsService {
  const NativeContactsService(this.api, this.routes);

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  Map<String, dynamic> _object(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const FormatException('Unexpected contact API response');
  }

  Future<List<NativeContact>> list({int page = 1, int perPage = 50}) async {
    final res = await api.getUri<Object?>(
      routes.recordsContactsList(page: page, perPage: perPage),
    );

    final items = _object(res.data)['contacts'];

    if (items is! List) {
      throw const FormatException('Missing contacts array');
    }

    return items.map((item) => NativeContact.fromJson(_object(item))).toList();
  }

  Future<NativeContact> get(String id) async {
    final res = await api.getUri<Object?>(routes.recordsContactGet(id));

    return NativeContact.fromJson(_object(_object(res.data)['contact']));
  }

  Future<NativeContact> create(Map<String, Object?> body) async {
    final res = await api.postUri<Object?>(
      routes.recordsContactCreate(),
      data: body,
    );

    return NativeContact.fromJson(_object(_object(res.data)['contact']));
  }

  Future<NativeContact> update(String id, Map<String, Object?> body) async {
    final res = await api.putUri<Object?>(
      routes.recordsContactUpdate(id),
      data: body,
    );

    return NativeContact.fromJson(_object(_object(res.data)['contact']));
  }

  /// Remove this contact's membership from the current app.
  /// Does not delete the canonical Native Contact.
  Future<void> removeFromApp(String id) async {
    await api.deleteUri<Object?>(routes.recordsContactMembershipRemove(id));
  }
}
