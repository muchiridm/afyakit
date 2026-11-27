// lib/features/records/health_profiles/profiles_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/records/health_profiles/profile_link_request_models.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profilesServiceProvider = Provider<ProfilesService>((ref) {
  final api = ref.afyakitClient;
  final routes = ref.afyakitRoutes;

  return ProfilesService(api: api, routes: routes);
});

final profilesServiceReadyProvider =
    FutureProvider.autoDispose<ProfilesService>((ref) async {
      final api = await ref.watch(afyakitClientFutureProvider.future);
      final routes = ref.afyakitRoutes;

      return ProfilesService(api: api, routes: routes);
    });

/// Eligible destination app, supplied by the backend for the authenticated owner.
class EligibleProfileApp {
  const EligibleProfileApp({required this.appId, required this.enrolled});
  final String appId;
  final bool enrolled;

  factory EligibleProfileApp.fromMap(Map<String, dynamic> map) {
    final id = (map['app_id'] ?? '').toString().trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id)) {
      throw const FormatException('Invalid eligible application');
    }
    return EligibleProfileApp(appId: id, enrolled: map['enrolled'] == true);
  }
}

class ProfileSharingOptions {
  const ProfileSharingOptions({
    required this.apps,
    required this.consentVersion,
    required this.consentNotice,
  });
  final List<EligibleProfileApp> apps;
  final String consentVersion;
  final String consentNotice;
}

class ProfilesService {
  const ProfilesService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  // ---------------------------------------------------------
  // Health Profiles
  // ---------------------------------------------------------

  Future<List<Profile>> list({
    String? search,
    String? accountNumber,
    ProfileContactRelationship? relationship,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final account = _optionalAccountNumber(accountNumber: accountNumber);

    final uri = routes.recordsProfilesList(
      search: _nullable(search),
      accountNumber: account,
      relationship: relationship?.name,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final body = _asMap(response.data);

    return _readProfiles(body['profiles']);
  }

  Future<Profile> get(String profileId) async {
    final id = _requiredId(profileId, 'profileId');

    final response = await api.getUri<Object?>(routes.recordsProfileGet(id));

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  Future<Profile> create(ProfileUpsertInput input) async {
    final data = _profileUpsertPayload(input);

    final response = await api.postUri<Object?>(
      routes.recordsProfileCreate(),
      data: data,
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  Future<Profile> update(String profileId, ProfileUpsertInput input) async {
    final id = _requiredId(profileId, 'profileId');

    final data = _profileUpsertPayload(input)
      ..remove('account_number')
      ..remove('relationship')
      ..remove('is_active')
      ..remove('app_ids');

    final response = await api.putUri<Object?>(
      routes.recordsProfileUpdate(id),
      data: data,
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  /// App staff explicitly enrol a verified Contact-linked patient in the
  /// current application. The server validates the app, Contact and link.
  /// This is NOT a tenant-wide profile search or an authorization bypass.
  Future<Profile> enrolInCurrentApp({
    required String profileId,
    required String accountNumber,
  }) async {
    final id = _requiredId(profileId, 'profileId');
    final account = NativeContact.requireAccountNumber(accountNumber);
    final profileUri = routes.recordsProfileGet(id);
    final enrolmentUri = profileUri.replace(
      path: '${profileUri.path}/enrolment',
      query: null,
    );
    final response = await api.postUri<Object?>(
      enrolmentUri,
      data: <String, Object?>{'account_number': account},
    );
    return _readProfile(_asMap(response.data)['profile']);
  }

  /// Release an existing profile into another app. A trusted, approved release
  /// record must already exist server-side; an arbitrary reference is rejected.
  Future<Profile> addAppEnrolment({
    required String profileId,
    required String destinationAppId,
    required String accountNumber,
    required String authorizationReference,
  }) async {
    final id = _requiredId(profileId, 'profileId');
    final destination = destinationAppId.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(destination)) {
      throw ArgumentError('Invalid destination application ID');
    }
    final account = NativeContact.requireAccountNumber(accountNumber);
    final approval = authorizationReference.trim();
    if (approval.isEmpty || approval.length > 256) {
      throw ArgumentError('An approved release reference is required');
    }
    final response = await api.postUri<Object?>(
      routes.recordsProfileAppEnrolments(id),
      data: <String, Object?>{
        'destination_app_id': destination,
        'account_number': account,
        'authorization_reference': approval,
      },
    );
    return _readProfile(_asMap(response.data)['profile']);
  }

  /// Self-service: available apps and the exact current consent notice.
  /// The backend checks the authenticated user's active self relationship.
  Future<ProfileSharingOptions> eligibleSelfApps(String profileId) async {
    final id = _requiredId(profileId, 'profileId');
    final response = await api.getUri<Object?>(routes.recordsProfileEligibleApps(id));
    final body = _asMap(response.data);
    final consent = _asMap(body['consent']);
    final version = (consent['version'] ?? '').toString().trim();
    final notice = (consent['notice'] ?? '').toString().trim();
    if (version.isEmpty || notice.isEmpty) {
      throw const FormatException('Sharing consent information unavailable');
    }
    final rawApps = body['apps'];
    if (rawApps is! List) throw const FormatException('Eligible apps missing');
    return ProfileSharingOptions(
      apps: rawApps.map((item) => EligibleProfileApp.fromMap(_asMap(item)))
          .toList(growable: false),
      consentVersion: version,
      consentNotice: notice,
    );
  }

  /// Share only the authenticated owner's profile, with explicit consent.
  /// The API resolves owner account and source app from the verified session.
  Future<Profile> shareOwnProfile({
    required String profileId,
    required String destinationAppId,
    required String consentVersion,
  }) async {
    final id = _requiredId(profileId, 'profileId');
    final app = destinationAppId.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(app)) {
      throw ArgumentError('Invalid destination app');
    }
    if (consentVersion.trim().isEmpty) throw ArgumentError('Consent version missing');
    final response = await api.postUri<Object?>(
      routes.recordsProfileShareSelf(id),
      data: <String, Object?>{
        'destination_app_id': app,
        'consent_accepted': true,
        'consent_version': consentVersion.trim(),
      },
    );
    return _readProfile(_asMap(response.data)['profile']);
  }

  /// Revoke another app's access without deleting the canonical Health Profile.
  Future<Profile> revokeOwnProfileApp({
    required String profileId,
    required String targetAppId,
  }) async {
    final id = _requiredId(profileId, 'profileId');
    final app = targetAppId.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(app)) {
      throw ArgumentError('Invalid destination app');
    }
    final response = await api.deleteUri<Object?>(
      routes.recordsProfileRevokeSelf(id, app),
    );
    return _readProfile(_asMap(response.data)['profile']);
  }

  /// Removes another application's enrolment, without deleting profile data.
  Future<Profile> removeAppEnrolment({
    required String profileId,
    required String targetAppId,
    required String reason,
  }) async {
    final id = _requiredId(profileId, 'profileId');
    final target = targetAppId.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(target)) {
      throw ArgumentError('Invalid target application ID');
    }
    final why = reason.trim();
    if (why.isEmpty || why.length > 512) {
      throw ArgumentError('A removal reason (up to 512 characters) is required');
    }
    final response = await api.deleteUri<Object?>(
      routes.recordsProfileAppEnrolmentRemove(id, target),
      data: <String, Object?>{'reason': why},
    );
    return _readProfile(_asMap(response.data)['profile']);
  }

  Future<void> delete(String profileId) async {
    final id = _requiredId(profileId, 'profileId');

    await api.deleteUri<Object?>(routes.recordsProfileDelete(id));
  }

  /// Existing DELETE endpoint performs a soft deactivation.
  Future<void> deactivate(String profileId) => delete(profileId);

  /// Reactivates the profile without changing any historical clinical fields.
  /// Contact-profile links deactivated previously remain inactive by design.
  Future<Profile> reactivate(String profileId) async {
    final id = _requiredId(profileId, 'profileId');
    final response = await api.putUri<Object?>(
      routes.recordsProfileUpdate(id),
      data: <String, Object?>{'is_active': true},
    );
    return _readProfile(_asMap(response.data)['profile']);
  }

  /// Read-only purge dependency report. Requires platform superadmin on the API.
  /// No frontend decision may override the backend's can_purge result.
  Future<ProfilePurgeReport> inspectPurgeDependencies(String profileId) async {
    final response = await api.getUri<Object?>(
      routes.recordsProfileDependencies(_requiredId(profileId, 'profileId')),
    );
    return ProfilePurgeReport.fromJson(_asMap(_asMap(response.data)['report']));
  }

  /// Superadmin-only permanent purge. The backend re-checks dependencies,
  /// the explicit identifier, retention attestation and reason.
  /// This is NOT the member unlink / staff deactivate endpoint.
  Future<void> permanentlyDelete(
    String profileId, {
    required String confirmation,
    required String reason,
    required bool retentionReviewed,
  }) async {
    final id = _requiredId(profileId, 'profileId');
    if (confirmation.trim() != id) {
      throw ArgumentError(
        'Type the exact Health Profile ID to confirm deletion',
      );
    }
    if (reason.trim().length < 10) {
      throw ArgumentError(
        'Provide a deletion reason of at least 10 characters',
      );
    }
    if (!retentionReviewed) {
      throw ArgumentError('Clinical retention review must be confirmed');
    }
    await api.postUri<Object?>(
      routes.recordsProfilePurge(id),
      data: <String, Object?>{
        'confirmation': confirmation.trim(),
        'reason': reason.trim(),
        'retention_reviewed': true,
      },
    );
  }

  // ---------------------------------------------------------
  // Staff Profile–Native Contact Links
  // ---------------------------------------------------------

  /// Links a Health Profile to a canonical Native Contact.
  ///
  /// The account number identifies a person or organisation contact.
  ///
  /// The backend validates Contact identity, app enrolment,
  /// relationship permissions and any required authorisation.
  Future<Profile> linkContact(
    String profileId,
    ProfileContactLinkInput input,
  ) async {
    final id = _requiredId(profileId, 'profileId');

    final account = NativeContact.requireAccountNumber(input.accountNumber);

    final response = await api.postUri<Object?>(
      routes.recordsProfileLinkedContactCreate(id),
      data: <String, Object?>{
        'account_number': account,
        'relationship': input.relationship.name,
        'is_active': input.isActive,
      },
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  /// Deactivates the relationship between a Health Profile
  /// and a Native Contact without deleting either record.
  ///
  Future<Profile> delinkContact({
    required String profileId,
    String? accountNumber,
  }) async {
    final pid = _requiredId(profileId, 'profileId');

    final account = NativeContact.requireAccountNumber(accountNumber);

    final response = await api.deleteUri<Object?>(
      routes.recordsProfileLinkedContactDelete(
        profileId: pid,
        accountNumber: account,
      ),
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  // ---------------------------------------------------------
  // Independent profile relationships and payer account links
  // ---------------------------------------------------------

  Future<List<RelatedProfile>> listRelatedProfiles(String profileId) async {
    final response = await api.getUri<Object?>(
      routes.recordsProfileRelationshipsList(
        _requiredId(profileId, 'profileId'),
      ),
    );
    final body = _asMap(response.data);
    return _asListOfMaps(
      body['linked_profiles'],
    ).map(RelatedProfile.fromJson).toList(growable: false);
  }

  // Profile-to-profile relationships are inferred, never written.
  // To change them, staff corrects the underlying Native Contact links.

  /// Staff-only under backend v2. Do not fetch in member mode.
  Future<List<ProfileLinkedContact>> listLinkedPayers(String profileId) async {
    final response = await api.getUri<Object?>(
      routes.recordsProfileLinkedContactsList(
        _requiredId(profileId, 'profileId'),
      ),
    );
    return _asListOfMaps(
      _asMap(response.data)['linked_payers'],
    ).map(ProfileLinkedContact.fromJson).toList(growable: false);
  }

  // ---------------------------------------------------------
  // Profile Link Requests
  // ---------------------------------------------------------

  Future<ProfileLinkRequest> createLinkRequest(
    String profileId,
    ProfileLinkRequestCreateInput input,
  ) async {
    final id = _requiredId(profileId, 'profileId');

    final response = await api.postUri<Object?>(
      routes.recordsProfileLinkRequestCreate(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readLinkRequest(body['request']);
  }

  Future<List<ProfileLinkRequest>> listLinkRequests({
    ProfileLinkRequestStatus? status,
    String? profileId,
    int perPage = 50,
    int page = 1,
  }) async {
    final uri = routes.recordsProfileLinkRequestsList(
      status: status?.wire,
      profileId: _nullable(profileId),
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final body = _asMap(response.data);

    return _readLinkRequests(body['requests']);
  }

  Future<ProfileLinkRequest> approveLinkRequest(
    String requestId,
    ProfileLinkRequestApproveInput input,
  ) async {
    final id = _requiredId(requestId, 'requestId');

    final response = await api.postUri<Object?>(
      routes.recordsProfileLinkRequestApprove(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readLinkRequest(body['request']);
  }

  Future<ProfileLinkRequest> rejectLinkRequest(
    String requestId,
    ProfileLinkRequestRejectInput input,
  ) async {
    final id = _requiredId(requestId, 'requestId');

    final response = await api.postUri<Object?>(
      routes.recordsProfileLinkRequestReject(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readLinkRequest(body['request']);
  }

  // ---------------------------------------------------------
  // Native Contact Identity Helpers
  // ---------------------------------------------------------

  static String? _optionalAccountNumber({String? accountNumber}) {
    final account = _nullable(accountNumber);
    return account == null ? null : NativeContact.requireAccountNumber(account);
  }

  static Map<String, Object?> _profileUpsertPayload(ProfileUpsertInput input) {
    final data = Map<String, Object?>.from(input.toJson());
    final account = _optionalAccountNumber(accountNumber: input.accountNumber);
    if (account != null) {
      data['account_number'] = account;
    } else {
      data.remove('account_number');
    }
    return data;
  }

  // ---------------------------------------------------------
  // Response Helpers
  // ---------------------------------------------------------

  static Profile _readProfile(Object? value) {
    return Profile.fromJson(_asMap(value));
  }

  static List<Profile> _readProfiles(Object? value) {
    return _asListOfMaps(value).map(Profile.fromJson).toList(growable: false);
  }

  static ProfileLinkRequest _readLinkRequest(Object? value) {
    return ProfileLinkRequest.fromJson(_asMap(value));
  }

  static List<ProfileLinkRequest> _readLinkRequests(Object? value) {
    return _asListOfMaps(
      value,
    ).map(ProfileLinkRequest.fromJson).toList(growable: false);
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, dynamic value) => MapEntry(key.toString(), value as Object?),
      );
    }

    throw const FormatException('Expected object map');
  }

  static List<Map<String, Object?>> _asListOfMaps(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, dynamic value) => MapEntry(key.toString(), value as Object?),
          ),
        )
        .toList(growable: false);
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

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}

/// A read-only snapshot of backend purge blockers. Never authorises deletion.
class ProfilePurgeReport {
  const ProfilePurgeReport({
    required this.profileId,
    required this.isActive,
    required this.blockers,
    this.references = const <String, bool>{},
    required this.unchecked,
    required this.canPurge,
  });

  final String profileId;
  final bool isActive;
  final Map<String, bool> blockers;
  final Map<String, bool> references;
  final List<String> unchecked;
  final bool canPurge;

  static Map<String, bool> _readBoolMap(Object? raw) {
    if (raw is! Map) return const <String, bool>{};
    return <String, bool>{
      for (final entry in raw.entries)
        if (entry.value is bool) entry.key.toString(): entry.value as bool,
    };
  }

  factory ProfilePurgeReport.fromJson(Map<String, Object?> json) {
    final raw = json['blockers'];
    final blockers = <String, bool>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.value is bool) {
          blockers[entry.key.toString()] = entry.value as bool;
        }
      }
    }
    return ProfilePurgeReport(
      profileId: json['profile_id']?.toString() ?? '',
      isActive: json['is_active'] == true,
      blockers: blockers,
      references: _readBoolMap(json['references']),
      unchecked: (json['unchecked'] is List)
          ? (json['unchecked'] as List)
                .map((e) => e.toString())
                .toList(growable: false)
          : const <String>[],
      canPurge: json['can_purge'] == true,
    );
  }
}
