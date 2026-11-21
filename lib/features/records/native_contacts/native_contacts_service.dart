import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  static final RegExp _accountPattern = RegExp(
    r'^AC-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
  );

  static Map<String, dynamic> _object(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Unexpected Native Contact API response');
  }

  static String _account(String value) {
    final account = value.trim().toUpperCase();
    if (!_accountPattern.hasMatch(account)) {
      throw ArgumentError.value(
        value,
        'accountNumber',
        'Expected canonical Native Contact account number (AC-XXXXXX)',
      );
    }
    return account;
  }

  static String _profileId(String value) {
    final id = value.trim();
    if (id.isEmpty || id.contains('/') || id.contains(r'\')) {
      throw ArgumentError.value(
        value,
        'profileId',
        'Invalid Health Profile ID',
      );
    }
    return id;
  }

  static Profile _profile(Object? value) => Profile.fromJson(_object(value));

  static List<Profile> _profileList(Object? body) {
    final items = _object(body)['profiles'];
    if (items is! List) {
      throw const FormatException('Missing linked profiles array');
    }
    return items.map((item) => _profile(item)).toList(growable: false);
  }

  // Member-scoped operations. The server derives the account from auth.
  Future<NativeContact> getMine() async {
    final res = await api.getUri<Object?>(routes.recordsMyContact());
    return NativeContact.fromJson(_object(_object(res.data)['contact']));
  }

  Future<NativeContact> updateMine(Map<String, Object?> body) async {
    const allowed = {'display_name', 'phone', 'mobile', 'email', 'id_number'};
    if (body.isEmpty || body.keys.any((key) => !allowed.contains(key))) {
      throw ArgumentError('Unsupported self-contact fields');
    }
    final res = await api.patchUri<Object?>(
      routes.recordsMyContact(),
      data: body,
    );
    return NativeContact.fromJson(_object(_object(res.data)['contact']));
  }

  /// Only profiles directly linked to the authenticated member's Contact.
  /// Does not accept an account number and does not grant clinical permissions.
  Future<List<Profile>> listMyLinkedHealthProfiles({
    int page = 1,
    int perPage = 50,
  }) async {
    final res = await api.getUri<Object?>(
      routes.recordsMyContactHealthProfilesList(page: page, perPage: perPage),
    );
    return _profileList(res.data);
  }

  // Staff-only Contact directory and mutations.
  Future<List<NativeContact>> list({int page = 1, int perPage = 50}) async {
    final res = await api.getUri<Object?>(
      routes.recordsContactsList(page: page, perPage: perPage),
    );
    final items = _object(res.data)['contacts'];
    if (items is! List) throw const FormatException('Missing contacts array');
    return items.map((item) => NativeContact.fromJson(_object(item))).toList();
  }

  /// Staff-only search. Uses the API's app-scoped search query parameter.
  /// Never call this service from a member-only screen.
  Future<List<NativeContact>> search(String query, {int perPage = 30}) async {
    final term = query.trim();
    if (term.isEmpty) return const <NativeContact>[];
    final base = routes.recordsContactsList(page: 1, perPage: perPage);
    final uri = base.replace(
      queryParameters: {...base.queryParameters, 'search': term},
    );
    final res = await api.getUri<Object?>(uri);
    final rows = _object(res.data)['contacts'];
    if (rows is! List) throw const FormatException('Missing contacts array');
    return rows.map((row) => NativeContact.fromJson(_object(row))).toList();
  }

  Future<NativeContact> get(String accountNumber) async {
    final res = await api.getUri<Object?>(
      routes.recordsContactGet(_account(accountNumber)),
    );
    return NativeContact.fromJson(_object(_object(res.data)['contact']));
  }

  Future<NativeContact> create(Map<String, Object?> body) async {
    final res = await api.postUri<Object?>(
      routes.recordsContactCreate(),
      data: body,
    );
    return NativeContact.fromJson(_object(_object(res.data)['contact']));
  }

  Future<NativeContact> update(
    String accountNumber,
    Map<String, Object?> body,
  ) async {
    if (body.containsKey('entity_type') || body.containsKey('status')) {
      throw ArgumentError(
        'entity_type and status cannot be changed through app contact editing',
      );
    }
    final res = await api.putUri<Object?>(
      routes.recordsContactUpdate(_account(accountNumber)),
      data: body,
    );
    return NativeContact.fromJson(_object(_object(res.data)['contact']));
  }

  Future<void> removeFromApp(String accountNumber) async {
    await api.deleteUri<Object?>(
      routes.recordsContactMembershipRemove(_account(accountNumber)),
    );
  }

  // Staff-only Contact -> Health Profile associations.
  // Sole source of truth: tenants/{tenantId}/health_profile_links.
  Future<List<Profile>> listLinkedHealthProfiles(
    String accountNumber, {
    int page = 1,
    int perPage = 50,
  }) async {
    final res = await api.getUri<Object?>(
      routes.recordsContactHealthProfilesList(
        _account(accountNumber),
        page: page,
        perPage: perPage,
      ),
    );
    return _profileList(res.data);
  }

  /// The relationship describes the patient relative to the Contact.
  Future<Profile> linkHealthProfile({
    required String accountNumber,
    required String profileId,
    required ProfileContactRelationship relationship,
  }) async {
    final account = _account(accountNumber);
    final id = _profileId(profileId);
    final res = await api.postUri<Object?>(
      routes.recordsContactHealthProfileLinkCreate(account),
      data: <String, Object?>{
        'profile_id': id,
        'relationship': relationship.name,
      },
    );
    return _profile(_object(res.data)['profile']);
  }

  Future<Profile> updateHealthProfileLink({
    required String accountNumber,
    required String profileId,
    required ProfileContactRelationship relationship,
  }) async {
    final account = _account(accountNumber);
    final id = _profileId(profileId);
    final res = await api.putUri<Object?>(
      routes.recordsContactHealthProfileLinkUpdate(
        accountNumber: account,
        profileId: id,
      ),
      data: <String, Object?>{
        'profile_id': id,
        'relationship': relationship.name,
      },
    );
    return _profile(_object(res.data)['profile']);
  }

  Future<Profile> unlinkHealthProfile({
    required String accountNumber,
    required String profileId,
  }) async {
    final res = await api.deleteUri<Object?>(
      routes.recordsContactHealthProfileLinkDelete(
        accountNumber: _account(accountNumber),
        profileId: _profileId(profileId),
      ),
    );
    return _profile(_object(res.data)['profile']);
  }
}
