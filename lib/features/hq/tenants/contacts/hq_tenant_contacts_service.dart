// lib/features/hq/tenants/contacts/hq_tenant_contacts_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';

final hqTenantContactsServiceProvider = FutureProvider<HqTenantContactsService>((ref) async {
  final client = await ref.watch(afyakitClientFutureProvider.future);
  return HqTenantContactsService(client.dio, AfyaKitRoutes('afyakit'));
});

/// Explicit, limited HQ DTO; excludes verified credentials and internal fields.
class HqTenantContact {
  const HqTenantContact({
    required this.accountNumber,
    required this.displayName,
    required this.status,
    required this.appIds,
    required this.authLinked,
    this.entityType,
    this.contactType,
    this.updatedAt,
    this.companyName, this.phone, this.mobile, this.email,
    this.idNumber, this.isInsurancePayer = false,
  });

  final String accountNumber;
  final String displayName;
  final String status;
  final List<String> appIds;
  final bool authLinked;
  final String? entityType;
  final String? contactType;
  final DateTime? updatedAt;
  final String? companyName, phone, mobile, email, idNumber;
  final bool isInsurancePayer;

  factory HqTenantContact.fromJson(Map<String, dynamic> json) {
    final updated = json['updated_at'];
    return HqTenantContact(
      accountNumber: (json['account_number'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      appIds: (json['app_ids'] is List)
          ? (json['app_ids'] as List).whereType<String>().toList(growable: false)
          : const [],
      authLinked: json['auth_linked'] == true,
      entityType: json['entity_type']?.toString(),
      contactType: json['contact_type']?.toString(),
      updatedAt: updated is String ? DateTime.tryParse(updated) : null,
      companyName: json['company_name']?.toString(),
      phone: json['phone']?.toString(),
      mobile: json['mobile']?.toString(),
      email: json['email']?.toString(),
      idNumber: json['id_number']?.toString(),
      isInsurancePayer: json['is_insurance_payer'] == true,
    );
  }
}

class HqTenantContactsPage {
  const HqTenantContactsPage({required this.contacts, this.nextCursor});
  final List<HqTenantContact> contacts;
  final String? nextCursor;
}

/// Informational only. No API currently grants purge clearance through HQ.
class HqTenantContactDependencies {
  const HqTenantContactDependencies({
    required this.contact,
    required this.blockers,
    required this.references,
    required this.deletionAuthorised,
    required this.requiresIndependentRetentionReview,
  });

  final HqTenantContact contact;
  final List<String> blockers;
  final Map<String, bool> references;
  final bool deletionAuthorised;
  final bool requiresIndependentRetentionReview;
}

/// HQ two-person review status. Approval is NOT a permanent deletion.
class HqTenantContactsService {
  const HqTenantContactsService(this._dio, this._routes);
  final Dio _dio;
  final AfyaKitRoutes _routes;

  static Map<String, dynamic> _map(Object? body) {
    if (body is Map) return Map<String, dynamic>.from(body);
    throw const FormatException('Unexpected HQ Tenant Contacts response');
  }

  static String _tenant(String value) {
    final id = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id)) {
      throw ArgumentError.value(value, 'tenantId', 'Invalid tenant ID');
    }
    return id;
  }

  static String _account(String value) {
    final number = value.trim().toUpperCase();
    if (!RegExp(r'^AC-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$').hasMatch(number)) {
      throw ArgumentError.value(value, 'accountNumber', 'Invalid account number');
    }
    return number;
  }

  Future<HqTenantContactsPage> list(String tenantId, {int limit = 50, String? cursor}) async {
    if (limit < 1 || limit > 100) throw RangeError.range(limit, 1, 100, 'limit');
    final response = await _dio.getUri(_routes.listHqTenantContacts(
      _tenant(tenantId), limit: limit,
      cursor: cursor == null || cursor.trim().isEmpty ? null : _account(cursor),
    ));
    final data = _map(response.data);
    final rows = data['contacts'];
    if (rows is! List) throw const FormatException('Missing contacts list');
    return HqTenantContactsPage(
      contacts: rows.map((item) => HqTenantContact.fromJson(_map(item))).toList(growable: false),
      nextCursor: data['nextCursor'] is String ? data['nextCursor'] as String : null,
    );
  }

  Future<HqTenantContact> create(String tenantId, Map<String, Object?> body) async {
    final response = await _dio.postUri(_routes.listHqTenantContacts(_tenant(tenantId)), data: body);
    return HqTenantContact.fromJson(_map(_map(response.data)['contact']));
  }

  Future<HqTenantContact> update(String tenantId, String accountNumber, Map<String, Object?> body) async {
    final response = await _dio.patchUri(_routes.getHqTenantContact(_tenant(tenantId), _account(accountNumber)), data: body);
    return HqTenantContact.fromJson(_map(_map(response.data)['contact']));
  }

  Future<HqTenantContact> get(String tenantId, String accountNumber) async {
    final response = await _dio.getUri(
      _routes.getHqTenantContact(_tenant(tenantId), _account(accountNumber)),
    );
    return HqTenantContact.fromJson(_map(_map(response.data)['contact']));
  }

  Future<HqTenantContactDependencies> dependencies(String tenantId, String accountNumber) async {
    final response = await _dio.getUri(
      _routes.getHqTenantContactDependencies(_tenant(tenantId), _account(accountNumber)),
    );
    final data = _map(response.data);
    final refs = _map(data['references']);
    return HqTenantContactDependencies(
      contact: HqTenantContact.fromJson(_map(data['contact'])),
      blockers: (data['blockers'] is List)
          ? (data['blockers'] as List).whereType<String>().toList(growable: false)
          : const [],
      references: refs.map((key, value) => MapEntry(key, value == true)),
      deletionAuthorised: data['deletion_authorised'] == true,
      requiresIndependentRetentionReview: data['requires_independent_retention_review'] == true,
    );
  }

  Future<void> permanentlyDelete(String tenantId, String accountNumber, {required String reason}) async {
    final id = _tenant(tenantId);
    final account = _account(accountNumber);
    await _dio.deleteUri(
      _routes.permanentlyDeleteHqTenantContact(id, account),
      data: <String, Object?>{
        'confirm_account_number': account,
        'reason': _validReason(reason),
      },
    );
  }

  static String _validReason(String reason) {
    final explanation = reason.trim();
    if (explanation.length < 15 || explanation.length > 1000) {
      throw ArgumentError.value(reason, 'reason', 'Must contain 15–1000 characters');
    }
    return explanation;
  }

  Future<void> archive(String tenantId, String accountNumber, {required String reason}) =>
      _setStatus(tenantId, accountNumber, reason: reason, archive: true);

  Future<void> restore(String tenantId, String accountNumber, {required String reason}) =>
      _setStatus(tenantId, accountNumber, reason: reason, archive: false);

  Future<void> _setStatus(String tenantId, String accountNumber, {
    required String reason,
    required bool archive,
  }) async {
    final id = _tenant(tenantId);
    final account = _account(accountNumber);
    final explanation = reason.trim();
    if (explanation.length < 15 || explanation.length > 1000) {
      throw ArgumentError.value(reason, 'reason', 'Must contain 15–1000 characters');
    }
    await _dio.postUri(
      archive ? _routes.archiveHqTenantContact(id, account) : _routes.restoreHqTenantContact(id, account),
      data: <String, Object?>{
        'confirm_account_number': account,
        'reason': explanation,
      },
    );
  }
}
