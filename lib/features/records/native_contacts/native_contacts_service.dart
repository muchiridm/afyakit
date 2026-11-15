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

  // ─────────────────────────────────────────────
  // Response helpers
  // ─────────────────────────────────────────────

  static Map<String, dynamic> _object(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const FormatException('Unexpected Native Contact API response');
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

  static Profile _profile(Object? value) {
    return Profile.fromJson(_object(value));
  }

  static List<Profile> _profileList(Object? body) {
    final items = _object(body)['profiles'];

    if (items is! List) {
      throw const FormatException('Missing linked profiles array');
    }

    return items.map((item) => _profile(item)).toList(growable: false);
  }

  static NativeContact _parseContact(Object? value) =>
      NativeContact.fromJson(_object(value));

  static List<NativeContact> _parseContacts(Object? value) {
    if (value is! List) {
      throw const FormatException('Missing contacts array');
    }
    return value.map(_parseContact).toList(growable: false);
  }

  // ─────────────────────────────────────────────
  // Member-scoped operations
  //
  // The backend resolves the account from Auth.
  // ─────────────────────────────────────────────

  Future<NativeContact> getMine() async {
    final res = await api.getUri<Object?>(routes.recordsMyContact());

    return _parseContact(_object(res.data)['contact']);
  }

  Future<NativeContact> updateMine(Map<String, Object?> body) async {
    const allowed = {'first_name', 'last_name', 'phone', 'email', 'id_number'};

    if (body.isEmpty || body.keys.any((key) => !allowed.contains(key))) {
      throw ArgumentError('Unsupported self-contact fields');
    }

    final res = await api.patchUri<Object?>(
      routes.recordsMyContact(),
      data: body,
    );

    return _parseContact(_object(res.data)['contact']);
  }

  /// Member-owned Health Profile summaries.
  Future<List<Profile>> listMyLinkedHealthProfiles({
    int page = 1,
    int perPage = 50,
  }) async {
    final res = await api.getUri<Object?>(
      routes.recordsMyContactHealthProfilesList(page: page, perPage: perPage),
    );

    return _profileList(res.data);
  }

  // ─────────────────────────────────────────────
  // Staff-only Native Contact directory
  // ─────────────────────────────────────────────

  Future<List<NativeContact>> list({int page = 1, int perPage = 50}) async {
    final uri = routes.recordsContactsList(page: page, perPage: perPage);

    final res = await api.getUri<Object?>(uri);

    final items = _object(res.data)['contacts'];

    return _parseContacts(items);
  }

  /// Staff-only server-side search.
  Future<List<NativeContact>> search(String query, {int perPage = 30}) async {
    final term = query.trim();

    if (term.isEmpty) {
      return const <NativeContact>[];
    }

    final base = routes.recordsContactsList(page: 1, perPage: perPage);

    final uri = base.replace(
      queryParameters: {...base.queryParameters, 'search': term},
    );

    final res = await api.getUri<Object?>(uri);

    final rows = _object(res.data)['contacts'];

    return _parseContacts(rows);
  }

  // ─────────────────────────────────────────────
  // Individual contact
  // ─────────────────────────────────────────────

  Future<NativeContact> get(String accountNumber) async {
    final account = NativeContact.requireAccountNumber(accountNumber);

    final res = await api.getUri<Object?>(routes.recordsContactGet(account));

    return _parseContact(_object(res.data)['contact']);
  }

  // ─────────────────────────────────────────────
  // Contact creation
  // ─────────────────────────────────────────────

  Future<NativeContact> create(Map<String, Object?> body) async {
    final res = await api.postUri<Object?>(
      routes.recordsContactCreate(),
      data: body,
    );

    return _parseContact(_object(res.data)['contact']);
  }

  // ─────────────────────────────────────────────
  // Contact update
  // ─────────────────────────────────────────────

  Future<NativeContact> update(
    String accountNumber,
    Map<String, Object?> body,
  ) async {
    if (body.containsKey('entity_type') || body.containsKey('status')) {
      throw ArgumentError(
        'entity_type and status cannot be changed '
        'through app contact editing',
      );
    }

    final account = NativeContact.requireAccountNumber(accountNumber);

    final res = await api.putUri<Object?>(
      routes.recordsContactUpdate(account),
      data: body,
    );

    return _parseContact(_object(res.data)['contact']);
  }

  // ─────────────────────────────────────────────
  // Remove app membership
  // ─────────────────────────────────────────────

  Future<void> removeFromApp(String accountNumber) async {
    await api.deleteUri<Object?>(
      routes.recordsContactMembershipRemove(
        NativeContact.requireAccountNumber(accountNumber),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Contact ↔ Health Profile links
  //
  // The backend's HealthProfilesService owns links.
  // ─────────────────────────────────────────────

  Future<List<Profile>> listLinkedHealthProfiles(
    String accountNumber, {
    int page = 1,
    int perPage = 50,
  }) async {
    final res = await api.getUri<Object?>(
      routes.recordsContactHealthProfilesList(
        NativeContact.requireAccountNumber(accountNumber),
        page: page,
        perPage: perPage,
      ),
    );

    return _profileList(res.data);
  }

  /// Relationship describes the patient relative
  /// to the Contact.
  Future<Profile> linkHealthProfile({
    required String accountNumber,
    required String profileId,
    required ProfileContactRelationship relationship,
  }) async {
    final account = NativeContact.requireAccountNumber(accountNumber);
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
    final account = NativeContact.requireAccountNumber(accountNumber);
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
        accountNumber: NativeContact.requireAccountNumber(accountNumber),
        profileId: _profileId(profileId),
      ),
    );

    return _profile(_object(res.data)['profile']);
  }
}
