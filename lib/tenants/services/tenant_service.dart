import 'dart:async';
import 'dart:convert';

import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/tenants/models/tenant_dtos.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// ─────────────────────────────────────────────────────────────
/// Service
/// ─────────────────────────────────────────────────────────────
class TenantService {
  TenantService({required this.client, required this.routes});

  final ApiClient client;
  final ApiRoutes routes;

  Dio get _dio => client.dio;
  static const _json = Headers.jsonContentType;
  static const _tag = '[TenantService]';

  // ── helpers ─────────────────────────────────────────────────
  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)));
  }

  List<Map<String, dynamic>> _asList(Object? raw) {
    if (raw is List) {
      return raw
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    final m = _asMap(raw);
    final results = m['results'];
    if (results is List) {
      return results
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }

  Never _bad(Response r, String op) {
    final reason = r.data is Map ? (r.data as Map)['error'] : null;
    throw Exception('❌ $op failed (${r.statusCode}): ${reason ?? 'Unknown'}');
  }

  // ─────────────────────────────────────────────────────────────
  // Utils
  // ─────────────────────────────────────────────────────────────

  /// Lowercase, strip non [a-z0-9 -], collapse spaces to '-', collapse dashes.
  String slugify(String input) {
    final s = input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isNotEmpty ? s : 'tenant';
  }

  // ─────────────────────────────────────────────────────────────
  // Tenants – list / get / create / update / status / flags / owner
  // ─────────────────────────────────────────────────────────────

  Future<List<TenantSummary>> listTenants() async {
    final r = await _dio.getUri(routes.listTenants());
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'List tenants');
    final list = _asList(r.data).map(TenantSummary.fromJson).toList();
    if (kDebugMode) debugPrint('✅ $_tag Loaded ${list.length} tenants');
    return list;
  }

  /// Polling replacement for Firestore snapshots.
  Stream<List<TenantSummary>> streamTenants({
    Duration every = const Duration(seconds: 8),
  }) async* {
    // Emit immediately, then poll.
    yield await listTenants();
    yield* Stream.periodic(every).asyncMap((_) => listTenants());
  }

  Future<TenantSummary> getTenant(String slug) async {
    final r = await _dio.getUri(routes.getTenant(slug));
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Get tenant');
    return TenantSummary.fromJson(_asMap(r.data));
  }

  /// Returns the slug created by the server.
  Future<String> createTenant({
    required String displayName,
    String? slug,
    String primaryColor = '#1565C0',
    String? logoPath,
    Map<String, dynamic> flags = const {},
    String? ownerUid,
    String? ownerEmail,
    List<String> seedAdminUids = const [],
  }) async {
    final payload = <String, dynamic>{
      'displayName': displayName,
      if (slug != null && slug.trim().isNotEmpty) 'slug': slugify(slug),
      'primaryColor': primaryColor,
      if (logoPath != null && logoPath.isNotEmpty) 'logoPath': logoPath,
      'flags': flags,
      if (ownerUid != null && ownerUid.isNotEmpty) 'ownerUid': ownerUid,
      if (ownerEmail != null && ownerEmail.isNotEmpty) 'ownerEmail': ownerEmail,
      if (seedAdminUids.isNotEmpty) 'seedAdminUids': seedAdminUids,
    };

    final r = await _dio.postUri(
      routes.createTenant(),
      data: payload,
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Create tenant');

    final m = _asMap(r.data);
    final createdSlug = (m['slug'] ?? payload['slug'] ?? '').toString();
    if (kDebugMode) debugPrint('✅ $_tag Tenant created: $createdSlug');
    return createdSlug;
  }

  Future<void> setStatusBySlug(String slug, String status) async {
    final r = await _dio.postUri(
      routes.setTenantStatus(slug),
      data: {'status': status},
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Set tenant status');
    if (kDebugMode) debugPrint('✅ $_tag Tenant $slug → status=$status');
  }

  Future<void> updateTenant({
    required String slug,
    String? displayName,
    String? primaryColor,
    String? logoPath,
    Map<String, dynamic>? flags, // full replace (server-side merge is fine too)
  }) async {
    final payload = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (primaryColor != null) 'primaryColor': primaryColor,
      if (logoPath != null) 'logoPath': logoPath,
      if (flags != null) 'flags': flags,
    };
    if (payload.isEmpty) return;

    final r = await _dio.patchUri(
      routes.updateTenant(slug),
      data: payload,
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Update tenant');
    if (kDebugMode) debugPrint('✅ $_tag Tenant $slug updated: $payload');
  }

  Future<void> setFlag(String slug, String key, Object? value) async {
    final r = await _dio.patchUri(
      routes.setTenantFlag(slug, key),
      data: {'value': value},
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Set tenant flag');
    if (kDebugMode) debugPrint('✅ $_tag Tenant $slug flag[$key]=$value');
  }

  Future<void> transferOwnership({
    required String slug,
    required String newOwnerUid,
  }) async {
    final r = await _dio.postUri(
      routes.transferTenantOwner(slug),
      data: {'newOwnerUid': newOwnerUid},
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Transfer ownership');
    if (kDebugMode) debugPrint('✅ $_tag Tenant $slug owner → $newOwnerUid');
  }

  // ─────────────────────────────────────────────────────────────
  // Tenant Admins – list / add / remove
  // ─────────────────────────────────────────────────────────────

  Future<List<TenantAdminUser>> listAdmins(String slug) async {
    final r = await _dio.getUri(routes.listTenantAdmins(slug));
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'List admins');
    final list = _asList(r.data).map(TenantAdminUser.fromJson).toList();
    if (kDebugMode) debugPrint('✅ $_tag Loaded ${list.length} admins ($slug)');
    return list;
  }

  /// Polling replacement for Firestore admins stream.
  Stream<List<TenantAdminUser>> streamAdmins(
    String slug, {
    Duration every = const Duration(seconds: 8),
  }) async* {
    yield await listAdmins(slug);
    yield* Stream.periodic(every).asyncMap((_) => listAdmins(slug));
  }

  /// Add/upgrade an admin by uid or email.
  Future<void> addAdmin({
    required String slug,
    String? uid,
    String? email,
    String role = 'admin', // 'admin' | 'manager'
  }) async {
    if ((uid == null || uid.isEmpty) && (email == null || email.isEmpty)) {
      throw ArgumentError('Provide uid or email to add admin');
    }
    final payload = <String, dynamic>{
      if (uid != null && uid.isNotEmpty) 'uid': uid,
      if (email != null && email.isNotEmpty)
        'email': EmailHelper.normalize(email),
      'role': role,
    };
    final r = await _dio.postUri(
      routes.addTenantAdmin(slug),
      data: payload,
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Add admin');
    if (kDebugMode) debugPrint('✅ $_tag Admin added ($slug): $payload');
  }

  /// Soft-remove or hard-delete an admin membership.
  Future<void> removeAdmin({
    required String slug,
    required String uid,
    bool softDelete = true,
  }) async {
    final uri = softDelete
        ? routes
              .removeTenantAdmin(slug, uid)
              .replace(queryParameters: {'soft': '1'})
        : routes.removeTenantAdmin(slug, uid);

    final r = await _dio.deleteUri(uri);
    final ok = (r.statusCode == 204) || ((r.statusCode ?? 0) ~/ 100 == 2);
    if (!ok) _bad(r, 'Remove admin');
    if (kDebugMode) {
      debugPrint('🗑️ $_tag Admin removed ($slug): $uid soft=$softDelete');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Membership (back-compat helpers; wrappers around tenant endpoints)
  // ─────────────────────────────────────────────────────────────

  Future<InviteResult> inviteToTenant({
    required String email,
    String role = 'staff', // 'owner'|'admin'|'manager'|'staff'|'client'
  }) async {
    final payload = {'email': EmailHelper.normalize(email), 'role': role};
    final r = await _dio.postUri(routes.inviteToTenant(), data: payload);
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Invite to tenant');
    return InviteResult.fromJson(_asMap(r.data));
  }

  Future<void> revokeFromTenant({required String uid}) async {
    final r = await _dio.deleteUri(routes.revokeFromTenant(uid));
    final ok = (r.statusCode == 204) || ((r.statusCode ?? 0) ~/ 100 == 2);
    if (!ok) _bad(r, 'Revoke from tenant');
    if (kDebugMode) debugPrint('🗑️ $_tag Membership revoked: $uid');
  }
}
