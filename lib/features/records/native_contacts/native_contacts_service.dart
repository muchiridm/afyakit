import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:flutter/foundation.dart';
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
    r'^(?:AC|ORG)-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
  );

  static const String _diagnosticAccount = 'AC-2P33JS';

  // ─────────────────────────────────────────────
  // Response helpers
  // ─────────────────────────────────────────────

  static Map<String, dynamic> _object(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const FormatException('Unexpected Native Contact API response');
  }

  static String _account(String value) {
    final account = value.trim().toUpperCase();

    if (!_accountPattern.hasMatch(account)) {
      throw ArgumentError.value(
        value,
        'accountNumber',
        'Expected canonical Native Contact account number '
            '(AC-XXXXXX or ORG-XXXXXX)',
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

  // ─────────────────────────────────────────────
  // Diagnostic helpers
  //
  // Enabled only in debug mode.
  // Logs field presence, not personal details.
  // ─────────────────────────────────────────────

  static bool _hasValue(Map<String, dynamic> json, String key) {
    final value = json[key];

    return value != null && value.toString().trim().isNotEmpty;
  }

  static void _logContact(
    String source,
    Map<String, dynamic> json,
    NativeContact contact,
  ) {
    if (!kDebugMode) return;

    final account = contact.accountNumber;

    final hasFirst = _hasValue(json, 'first_name');
    final hasLast = _hasValue(json, 'last_name');
    final hasCompany = _hasValue(json, 'company_name');
    final hasDisplay = _hasValue(json, 'display_name');

    final derivedNamePresent = contact.displayName.trim().isNotEmpty;

    // Log individual records only when they are missing
    // a derived display name or are our diagnostic example.
    if (derivedNamePresent && account != _diagnosticAccount) {
      return;
    }

    debugPrint(
      '🧩 [native-contact][$source] '
      'account=$account '
      'entity=${contact.entityType} '
      'api.first=$hasFirst '
      'api.last=$hasLast '
      'api.company=$hasCompany '
      'api.display=$hasDisplay '
      'model.first=${contact.firstName?.isNotEmpty == true} '
      'model.last=${contact.lastName?.isNotEmpty == true} '
      'model.company=${contact.companyName?.isNotEmpty == true} '
      'derivedName=$derivedNamePresent',
    );

    if (account == _diagnosticAccount) {
      debugPrint(
        '🔎 [native-contact][KENNEDY-CHECK] '
        'rawKeys=${json.keys.toList()}',
      );
    }
  }

  static NativeContact _parseContact(Object? value, {required String source}) {
    final json = _object(value);

    final contact = NativeContact.fromJson(json);

    _logContact(source, json, contact);

    return contact;
  }

  static List<NativeContact> _parseContacts(
    Object? value, {
    required String source,
  }) {
    if (value is! List) {
      throw const FormatException('Missing contacts array');
    }

    final contacts = <NativeContact>[];

    int personCount = 0;
    int organizationCount = 0;
    int missingNames = 0;
    int missingPersonNames = 0;
    int missingOrganizationNames = 0;

    int apiFirstPresent = 0;
    int apiLastPresent = 0;
    int apiCompanyPresent = 0;
    int apiDisplayPresent = 0;

    for (final item in value) {
      final json = _object(item);

      if (_hasValue(json, 'first_name')) {
        apiFirstPresent++;
      }

      if (_hasValue(json, 'last_name')) {
        apiLastPresent++;
      }

      if (_hasValue(json, 'company_name')) {
        apiCompanyPresent++;
      }

      if (_hasValue(json, 'display_name')) {
        apiDisplayPresent++;
      }

      final contact = NativeContact.fromJson(json);

      contacts.add(contact);

      if (contact.isOrganization) {
        organizationCount++;
      } else {
        personCount++;
      }

      final nameMissing = contact.displayName.trim().isEmpty;

      if (nameMissing) {
        missingNames++;

        if (contact.isOrganization) {
          missingOrganizationNames++;
        } else {
          missingPersonNames++;
        }
      }

      _logContact(source, json, contact);
    }

    if (kDebugMode) {
      debugPrint(
        '📋 [native-contacts][$source] '
        'total=${contacts.length} '
        'persons=$personCount '
        'organizations=$organizationCount '
        'missingNames=$missingNames',
      );

      debugPrint(
        '📋 [native-contacts][$source][API-FIELDS] '
        'first_name=$apiFirstPresent '
        'last_name=$apiLastPresent '
        'company_name=$apiCompanyPresent '
        'display_name=$apiDisplayPresent',
      );

      debugPrint(
        '📋 [native-contacts][$source][MODEL] '
        'missingPersonNames=$missingPersonNames '
        'missingOrganizationNames=$missingOrganizationNames',
      );

      if (missingNames > 0) {
        debugPrint(
          '⚠️ [native-contacts][$source] '
          '$missingNames contacts have empty derived names.',
        );
      }
    }

    return contacts;
  }

  // ─────────────────────────────────────────────
  // Member-scoped operations
  //
  // The backend resolves the account from Auth.
  // ─────────────────────────────────────────────

  Future<NativeContact> getMine() async {
    final res = await api.getUri<Object?>(routes.recordsMyContact());

    return _parseContact(_object(res.data)['contact'], source: 'GET-ME');
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

    return _parseContact(_object(res.data)['contact'], source: 'PATCH-ME');
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

    if (kDebugMode) {
      debugPrint(
        '➡️ [native-contacts][LIST] '
        'page=$page perPage=$perPage',
      );
    }

    final res = await api.getUri<Object?>(uri);

    final items = _object(res.data)['contacts'];

    return _parseContacts(items, source: 'LIST');
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

    if (kDebugMode) {
      debugPrint(
        '➡️ [native-contacts][SEARCH] '
        'queryLength=${term.length}',
      );
    }

    final res = await api.getUri<Object?>(uri);

    final rows = _object(res.data)['contacts'];

    return _parseContacts(rows, source: 'SEARCH');
  }

  // ─────────────────────────────────────────────
  // Individual contact
  // ─────────────────────────────────────────────

  Future<NativeContact> get(String accountNumber) async {
    final account = _account(accountNumber);

    final res = await api.getUri<Object?>(routes.recordsContactGet(account));

    return _parseContact(_object(res.data)['contact'], source: 'GET');
  }

  // ─────────────────────────────────────────────
  // Contact creation
  // ─────────────────────────────────────────────

  Future<NativeContact> create(Map<String, Object?> body) async {
    final res = await api.postUri<Object?>(
      routes.recordsContactCreate(),
      data: body,
    );

    return _parseContact(_object(res.data)['contact'], source: 'CREATE');
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

    final account = _account(accountNumber);

    final res = await api.putUri<Object?>(
      routes.recordsContactUpdate(account),
      data: body,
    );

    return _parseContact(_object(res.data)['contact'], source: 'UPDATE');
  }

  // ─────────────────────────────────────────────
  // Remove app membership
  // ─────────────────────────────────────────────

  Future<void> removeFromApp(String accountNumber) async {
    await api.deleteUri<Object?>(
      routes.recordsContactMembershipRemove(_account(accountNumber)),
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
        _account(accountNumber),
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
