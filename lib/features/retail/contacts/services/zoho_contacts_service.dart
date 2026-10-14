import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

/// Zoho is only an accounting projection of a canonical Native Contact.
/// All arguments are Native Contact IDs (AC-XXXXXX), never Zoho IDs.
final zohoContactsServiceProvider = FutureProvider<ZohoContactsService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final api = await ref.watch(afyakitClientFutureProvider.future);
  return ZohoContactsService(api: api, routes: AfyaKitRoutes(tenantId));
});

final zohoMappedContactByNativeIdProvider = FutureProvider.family
    .autoDispose<ZohoMappedContact, String>((ref, nativeContactId) async {
      final service = await ref.watch(zohoContactsServiceProvider.future);
      return service.getMappedContact(nativeContactId);
    });

class ZohoContactMapping {
  const ZohoContactMapping({
    required this.nativeContactId,
    required this.zohoContactId,
  });

  final String nativeContactId;
  final String zohoContactId;

  factory ZohoContactMapping.fromJson(Map<String, dynamic> json) =>
      ZohoContactMapping(
        nativeContactId: (json['native_contact_id'] ?? '').toString(),
        zohoContactId: (json['zoho_contact_id'] ?? '').toString(),
      );
}

class ZohoMappedContact {
  const ZohoMappedContact({
    required this.nativeContactId,
    required this.zohoContactId,
    required this.contactName,
    required this.contactType,
    this.status,
    this.companyName,
    this.email,
    this.phone,
    this.mobile,
  });

  final String nativeContactId;
  final String zohoContactId;
  final String contactName;
  final String contactType;
  final String? status;
  final String? companyName;
  final String? email;
  final String? phone;
  final String? mobile;

  factory ZohoMappedContact.fromJson(Map<String, dynamic> json) =>
      ZohoMappedContact(
        nativeContactId: (json['native_contact_id'] ?? '').toString(),
        zohoContactId: (json['zoho_contact_id'] ?? '').toString(),
        contactName: (json['contact_name'] ?? '').toString(),
        contactType: (json['contact_type'] ?? '').toString(),
        status: json['status']?.toString(),
        companyName: json['company_name']?.toString(),
        email: json['email']?.toString(),
        phone: json['phone']?.toString(),
        mobile: json['mobile']?.toString(),
      );
}

class ZohoContactsService {
  const ZohoContactsService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  static Map<String, dynamic> _object(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Unexpected Zoho contact response');
  }

  static String _nativeId(String nativeContactId) {
    final id = nativeContactId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(nativeContactId, 'nativeContactId', 'Required');
    }
    return id;
  }

  /// GET /zoho/v1/contacts/:nativeContactId/mapping
  Future<ZohoContactMapping> getMapping(String nativeContactId) async {
    final res = await api.getUri<Object?>(
      routes.retailZohoContactMapping(_nativeId(nativeContactId)),
    );
    return ZohoContactMapping.fromJson(_object(_object(res.data)['mapping']));
  }

  /// GET /zoho/v1/contacts/:nativeContactId
  Future<ZohoMappedContact> getMappedContact(String nativeContactId) async {
    final res = await api.getUri<Object?>(
      routes.retailZohoMappedContact(_nativeId(nativeContactId)),
    );
    return ZohoMappedContact.fromJson(_object(_object(res.data)['contact']));
  }
}
