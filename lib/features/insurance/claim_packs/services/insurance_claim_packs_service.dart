// lib/features/insurance/claim_packs/services/insurance_claim_packs_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/insurance/claim_packs/models/insurance_claim_pack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final insuranceClaimPacksServiceProvider =
    FutureProvider<InsuranceClaimPacksService>((ref) async {
      final String tenantId = ref.watch(tenantIdProvider);
      final AfyaKitRoutes routes = AfyaKitRoutes(tenantId);
      final AfyaKitClient api = await ref.watch(
        afyakitClientFutureProvider.future,
      );

      return InsuranceClaimPacksService(api: api, routes: routes);
    });

class InsuranceClaimPacksService {
  const InsuranceClaimPacksService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  Future<List<InsuranceClaimPack>> list({
    String? search,
    String? membershipId,
    String? profileId,
    String? payerContactId,
    String? invoiceId,
    String? memberNo,
    String? authCode,
    String? insurerClaimNo,
    String? visitNo,
    String? prescriptionId,
    InsuranceClaimPackStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final Uri uri = routes.insuranceClaimPacksList(
      search: _nullable(search),
      membershipId: _nullable(membershipId),
      profileId: _nullable(profileId),
      payerContactId: _nullable(payerContactId),
      invoiceId: _nullable(invoiceId),
      memberNo: _nullable(memberNo),
      authCode: _nullable(authCode),
      insurerClaimNo: _nullable(insurerClaimNo),
      visitNo: _nullable(visitNo),
      prescriptionId: _nullable(prescriptionId),
      status: status?.wire,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final Map<String, Object?> body = _asMap(response.data);

    return _readClaimPacks(body['claim_packs']);
  }

  Future<List<InsuranceClaimPack>> listForProfile({
    required String profileId,
    String? search,
    String? membershipId,
    String? payerContactId,
    String? invoiceId,
    String? memberNo,
    String? authCode,
    String? insurerClaimNo,
    String? visitNo,
    String? prescriptionId,
    InsuranceClaimPackStatus? status,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final String cleanProfileId = _requiredId(profileId, 'profileId');

    final Uri uri = routes.insuranceClaimPacksListForProfile(
      profileId: cleanProfileId,
      search: _nullable(search),
      membershipId: _nullable(membershipId),
      payerContactId: _nullable(payerContactId),
      invoiceId: _nullable(invoiceId),
      memberNo: _nullable(memberNo),
      authCode: _nullable(authCode),
      insurerClaimNo: _nullable(insurerClaimNo),
      visitNo: _nullable(visitNo),
      prescriptionId: _nullable(prescriptionId),
      status: status?.wire,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final Map<String, Object?> body = _asMap(response.data);

    return _readClaimPacks(body['claim_packs']);
  }

  Future<InsuranceClaimPack> get({
    required String profileId,
    required String claimPackId,
  }) async {
    final String cleanProfileId = _requiredId(profileId, 'profileId');
    final String cleanClaimPackId = _requiredId(claimPackId, 'claimPackId');

    final response = await api.getUri<Object?>(
      routes.insuranceClaimPackGet(
        profileId: cleanProfileId,
        claimPackId: cleanClaimPackId,
      ),
    );

    final Map<String, Object?> body = _asMap(response.data);
    return _readClaimPack(body['claim_pack']);
  }

  Future<InsuranceClaimPack> create({
    required String profileId,
    required InsuranceClaimPackCreateInput input,
  }) async {
    final String cleanProfileId = _requiredId(profileId, 'profileId');

    final response = await api.postUri<Object?>(
      routes.insuranceClaimPackCreate(profileId: cleanProfileId),
      data: input.toJson(),
    );

    final Map<String, Object?> body = _asMap(response.data);
    return _readClaimPack(body['claim_pack']);
  }

  Future<InsuranceClaimPack> update({
    required String profileId,
    required String claimPackId,
    required InsuranceClaimPackUpdateInput input,
  }) async {
    final String cleanProfileId = _requiredId(profileId, 'profileId');
    final String cleanClaimPackId = _requiredId(claimPackId, 'claimPackId');

    final response = await api.putUri<Object?>(
      routes.insuranceClaimPackUpdate(
        profileId: cleanProfileId,
        claimPackId: cleanClaimPackId,
      ),
      data: input.toJson(),
    );

    final Map<String, Object?> body = _asMap(response.data);
    return _readClaimPack(body['claim_pack']);
  }

  Future<void> delete({
    required String profileId,
    required String claimPackId,
  }) async {
    final String cleanProfileId = _requiredId(profileId, 'profileId');
    final String cleanClaimPackId = _requiredId(claimPackId, 'claimPackId');

    await api.deleteUri<Object?>(
      routes.insuranceClaimPackDelete(
        profileId: cleanProfileId,
        claimPackId: cleanClaimPackId,
      ),
    );
  }

  static InsuranceClaimPack _readClaimPack(Object? value) {
    return InsuranceClaimPack.fromJson(_asMap(value));
  }

  static List<InsuranceClaimPack> _readClaimPacks(Object? value) {
    return _asListOfMaps(
      value,
    ).map(InsuranceClaimPack.fromJson).toList(growable: false);
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) return value;

    if (value is Map) {
      final Map<String, Object?> output = <String, Object?>{};

      for (final MapEntry<Object?, Object?> entry
          in value.entries.cast<MapEntry<Object?, Object?>>()) {
        output[entry.key.toString()] = entry.value;
      }

      return output;
    }

    throw const FormatException('Expected object map');
  }

  static List<Map<String, Object?>> _asListOfMaps(Object? value) {
    if (value is! List) return const <Map<String, Object?>>[];

    final List<Map<String, Object?>> output = <Map<String, Object?>>[];

    for (final Object? item in value) {
      if (item is Map || item is Map<String, Object?>) {
        output.add(_asMap(item));
      }
    }

    return output;
  }

  static String _requiredId(String value, String name) {
    final String id = value.trim();

    if (id.isEmpty) {
      throw ArgumentError.value(value, name, '$name is empty');
    }

    return id;
  }

  static String? _nullable(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
