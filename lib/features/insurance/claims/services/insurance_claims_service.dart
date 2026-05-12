// lib/features/insurance/claims/services/insurance_claims_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/insurance/claims/models/insurance_claim.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final insuranceClaimsServiceProvider = FutureProvider<InsuranceClaimsService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final routes = AfyaKitRoutes(tenantId);
  final api = await ref.watch(afyakitClientFutureProvider.future);

  return InsuranceClaimsService(api: api, routes: routes);
});

class InsuranceClaimsService {
  const InsuranceClaimsService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  Future<List<InsuranceClaim>> list({
    String? search,
    String? membershipId,
    String? patientId,
    String? patientNo,
    String? payerContactId,
    String? invoiceId,
    String? memberNumber,
    String? scheme,
    String? authorizationNumber,
    String? claimNumber,
    String? visitNumber,
    String? prescriptionNumber,
    InsuranceClaimStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final uri = routes.insuranceClaimsList(
      search: _nullable(search),
      membershipId: _nullable(membershipId),
      patientId: _nullable(patientId),
      patientNo: _nullable(patientNo),
      payerContactId: _nullable(payerContactId),
      invoiceId: _nullable(invoiceId),
      memberNumber: _nullable(memberNumber),
      scheme: _nullable(scheme),
      authorizationNumber: _nullable(authorizationNumber),
      claimNumber: _nullable(claimNumber),
      visitNumber: _nullable(visitNumber),
      prescriptionNumber: _nullable(prescriptionNumber),
      status: status?.wire,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final body = _asMap(response.data);

    return _readClaims(body['claims']);
  }

  Future<InsuranceClaim> get(String claimId) async {
    final id = _requiredId(claimId, 'claimId');

    final response = await api.getUri<Object?>(routes.insuranceClaimGet(id));

    final body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  /// Creates the insurance claim.
  ///
  /// Backend responsibility:
  /// - resolves membership_id
  /// - saves claim snapshot
  /// - maps claim fields to Zoho custom fields
  /// - updates the linked Zoho invoice
  Future<InsuranceClaim> create(InsuranceClaimUpsertInput input) async {
    final response = await api.postUri<Object?>(
      routes.insuranceClaimCreate(),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  /// Updates the insurance claim.
  ///
  /// Backend responsibility:
  /// - updates claim snapshot
  /// - remaps claim fields to Zoho custom fields
  /// - updates the linked Zoho invoice
  Future<InsuranceClaim> update(
    String claimId,
    InsuranceClaimUpsertInput input,
  ) async {
    final id = _requiredId(claimId, 'claimId');

    final response = await api.putUri<Object?>(
      routes.insuranceClaimUpdate(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readClaim(body['claim']);
  }

  Future<void> delete(String claimId) async {
    final id = _requiredId(claimId, 'claimId');

    await api.deleteUri<Object?>(routes.insuranceClaimDelete(id));
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

  static InsuranceClaim _readClaim(Object? value) {
    return InsuranceClaim.fromJson(_asMap(value));
  }

  static List<InsuranceClaim> _readClaims(Object? value) {
    return _asListOfMaps(
      value,
    ).map(InsuranceClaim.fromJson).toList(growable: false);
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
