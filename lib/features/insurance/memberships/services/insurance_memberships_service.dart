// lib/features/insurance/memberships/services/insurance_memberships_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final insuranceMembershipsServiceProvider =
    FutureProvider<InsuranceMembershipsService>((ref) async {
      final tenantId = ref.watch(tenantIdProvider);
      final routes = AfyaKitRoutes(tenantId);
      final api = await ref.watch(afyakitClientFutureProvider.future);

      return InsuranceMembershipsService(api: api, routes: routes);
    });

class InsuranceMembershipsService {
  const InsuranceMembershipsService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  Future<List<InsuranceMembership>> list({
    String? search,
    String? patientId,
    String? patientNo,
    String? payerContactId,
    String? memberNo,
    String? scheme,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final uri = routes.insuranceMembershipsList(
      search: _nullable(search),
      patientId: _nullable(patientId),
      patientNo: _nullable(patientNo),
      payerContactId: _nullable(payerContactId),
      memberNo: _nullable(memberNo),
      scheme: _nullable(scheme),
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final body = _asMap(response.data);

    return _readMemberships(body['memberships']);
  }

  Future<InsuranceMembership> get(String membershipId) async {
    final id = _requiredId(membershipId, 'membershipId');

    final response = await api.getUri<Object?>(
      routes.insuranceMembershipGet(id),
    );

    final body = _asMap(response.data);
    return _readMembership(body['membership']);
  }

  Future<InsuranceMembership> create(
    InsuranceMembershipUpsertInput input,
  ) async {
    final response = await api.postUri<Object?>(
      routes.insuranceMembershipCreate(),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readMembership(body['membership']);
  }

  Future<InsuranceMembership> update(
    String membershipId,
    InsuranceMembershipUpsertInput input,
  ) async {
    final id = _requiredId(membershipId, 'membershipId');

    final response = await api.putUri<Object?>(
      routes.insuranceMembershipUpdate(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readMembership(body['membership']);
  }

  Future<void> delete(String membershipId) async {
    final id = _requiredId(membershipId, 'membershipId');

    await api.deleteUri<Object?>(routes.insuranceMembershipDelete(id));
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) return value;

    if (value is Map) {
      return value.map(
        (key, dynamic value) => MapEntry(key.toString(), value as Object?),
      );
    }

    throw const FormatException('Expected object map');
  }

  static List<Map<String, Object?>> _asListOfMaps(Object? value) {
    if (value is! List) return const <Map<String, Object?>>[];

    return value
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, dynamic value) => MapEntry(key.toString(), value as Object?),
          ),
        )
        .toList(growable: false);
  }

  static InsuranceMembership _readMembership(Object? value) {
    return InsuranceMembership.fromJson(_asMap(value));
  }

  static List<InsuranceMembership> _readMemberships(Object? value) {
    return _asListOfMaps(
      value,
    ).map(InsuranceMembership.fromJson).toList(growable: false);
  }

  static String _requiredId(String value, String name) {
    final id = value.trim();

    if (id.isEmpty) {
      throw ArgumentError.value(value, name, '$name is empty');
    }

    return id;
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
