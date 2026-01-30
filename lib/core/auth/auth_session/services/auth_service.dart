// lib/core/auth/services/auth_service.dart

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';

import 'package:afyakit/core/auth/auth_session/models/start_response.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

final authServiceProvider = FutureProvider.family<AuthService, String>((
  ref,
  tenantId,
) async {
  final api = await AfyaKitClient.create(
    baseUrl: apiBaseUrl(tenantId),
    getToken: () async => fb.FirebaseAuth.instance.currentUser?.getIdToken(),
    getFreshToken: () async =>
        fb.FirebaseAuth.instance.currentUser?.getIdToken(true),
  );

  return AuthService(
    tenantId: tenantId,
    client: api,
    routes: AfyaKitRoutes(tenantId),
  );
});

typedef JsonMap = Map<String, dynamic>;

enum OtpNextStep { collectEmail, collectName, done }

OtpNextStep _parseNextStep(String? s) {
  switch ((s ?? '').trim()) {
    case 'collect_email':
      return OtpNextStep.collectEmail;
    case 'collect_name':
      return OtpNextStep.collectName;
    default:
      return OtpNextStep.done;
  }
}

class OtpVerifyApiResult {
  const OtpVerifyApiResult({
    required this.ok,
    required this.customToken,
    required this.uid,
    required this.tenant,
    required this.next,
  });

  final bool ok;
  final String? customToken;
  final String? uid;
  final String? tenant;
  final OtpNextStep next;

  static String? _readTrimmedString(Object? v) {
    final s = v is String ? v.trim() : null;
    return (s == null || s.isEmpty) ? null : s;
  }

  factory OtpVerifyApiResult.fromJson(JsonMap j) {
    final ok = j['ok'] == true || j['success'] == true;
    return OtpVerifyApiResult(
      ok: ok,
      customToken: _readTrimmedString(j['customToken']),
      uid: _readTrimmedString(j['uid']),
      tenant: _readTrimmedString(j['tenant'] ?? j['tenantId']),
      next: _parseNextStep(_readTrimmedString(j['next'])),
    );
  }
}

class AuthService {
  AuthService({
    required this.tenantId,
    required this.client,
    required this.routes,
  });

  final String tenantId;
  final AfyaKitClient client;
  final AfyaKitRoutes routes;

  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;
  Dio get _dio => client.dio;

  AuthUser? _cachedUser;
  AuthUser? get currentUser => _cachedUser;

  // ─────────────────────────────────────────────
  // Options
  // ─────────────────────────────────────────────

  Options get _skipAuth =>
      Options(extra: const <String, dynamic>{'skipAuth': true});

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  JsonMap _asJsonMap(Object? data) {
    if (data is JsonMap) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // ignore
      }
    }

    return const <String, dynamic>{};
  }

  StartResponse _parseStartResponse(Object? data) {
    final m = _asJsonMap(data);
    return StartResponse(
      ok: m['ok'] == true,
      throttled: m['throttled'] == true,
      attemptId: m['attemptId'] is String ? (m['attemptId'] as String) : null,
      expiresInSec: m['expiresInSec'] is num
          ? (m['expiresInSec'] as num).toInt()
          : null,
      channel: m['channel'] is String ? (m['channel'] as String) : null,
      maskedTo: m['maskedTo'] is String ? (m['maskedTo'] as String) : null,
    );
  }

  static String _requireTrimmed(String value, String message) {
    final v = value.trim();
    if (v.isEmpty) throw ArgumentError(message);
    return v;
  }

  static void _ensureAttemptId(StartResponse out, String message) {
    if (out.throttled == true) return;
    if (out.ok == true && (out.attemptId ?? '').trim().isEmpty) {
      throw StateError(message);
    }
  }

  Never _failDio(String op, DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    throw StateError(
      '$op failed'
      '${status != null ? ' (HTTP $status)' : ''}'
      '${body != null ? ': $body' : ''}',
    );
  }

  /// Always returns an Authorization header with a FRESH token.
  /// Useful for "verify email" flows or anything that must be authed now.
  Future<Options> _authHeaderFresh() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) {
      throw StateError('Not signed in — missing Firebase user.');
    }

    final token = (await fbUser.getIdToken(true))?.trim() ?? '';
    if (token.isEmpty) {
      throw StateError('Not signed in — missing Firebase idToken.');
    }

    return Options(
      headers: <String, dynamic>{'Authorization': 'Bearer $token'},
      extra: const <String, dynamic>{
        // Explicitly ensure no “skip” logic can strip headers.
        'skipAuth': false,
        // Optional: if your interceptor uses this to refresh tokens
        'forceFreshToken': true,
      },
    );
  }

  // ─────────────────────────────────────────────
  // PUBLIC: start AUTO phone otp (sms/email)
  // ─────────────────────────────────────────────

  Future<StartResponse> startAutoOtp(
    String phoneInput, {
    int codeLength = 6,
  }) async {
    final phone = _requireTrimmed(phoneInput, 'Phone number is required');

    try {
      final res = await _dio.postUri(
        routes.autoStart(),
        data: <String, dynamic>{'phoneNumber': phone, 'codeLength': codeLength},
        options: _skipAuth,
      );

      final out = _parseStartResponse(res.data);
      _ensureAttemptId(
        out,
        'OTP start succeeded but no attemptId was returned.',
      );
      return out;
    } on DioException catch (e) {
      _failDio('startAutoOtp', e);
    }
  }

  // ─────────────────────────────────────────────
  // PUBLIC: email login otp (NO token)
  // ─────────────────────────────────────────────

  Future<StartResponse> startEmailLoginOtp({
    required String email,
    int codeLength = 6,
  }) async {
    final e = _requireTrimmed(email, 'Email is required');

    try {
      final res = await _dio.postUri(
        routes.emailStart(),
        data: <String, dynamic>{'email': e, 'codeLength': codeLength},
        options: _skipAuth,
      );

      final out = _parseStartResponse(res.data);
      _ensureAttemptId(
        out,
        'Email OTP start succeeded but no attemptId was returned.',
      );
      return out;
    } on DioException catch (ex) {
      _failDio('startEmailLoginOtp', ex);
    }
  }

  // ─────────────────────────────────────────────
  // AUTH REQUIRED: verify-email otp (MUST include bearer)
  // ─────────────────────────────────────────────

  Future<StartResponse> startVerifyEmailOtp({
    required String email,
    int codeLength = 6,
  }) async {
    final e = _requireTrimmed(email, 'Email is required');

    final authed = await _authHeaderFresh();

    try {
      final res = await _dio.postUri(
        routes.emailStart(),
        data: <String, dynamic>{
          'email': e,
          'codeLength': codeLength,
          'purpose': 'verify_email',
        },
        options: authed,
      );

      final out = _parseStartResponse(res.data);
      _ensureAttemptId(
        out,
        'Verify-email OTP start succeeded but no attemptId was returned.',
      );
      return out;
    } on DioException catch (ex) {
      _failDio('startVerifyEmailOtp', ex);
    }
  }

  // ─────────────────────────────────────────────
  // PUBLIC: otp verify (returns customToken)
  // ─────────────────────────────────────────────

  Future<OtpVerifyApiResult> verifyOtpRaw({
    required String attemptId,
    required String code,
    String? firstName,
    String? lastName,
    String? companyName,
  }) async {
    final a = _requireTrimmed(attemptId, 'attemptId is required');
    final c = _requireTrimmed(code, 'code is required');

    final payload = <String, dynamic>{
      'attemptId': a,
      'code': c,
      if ((firstName ?? '').trim().isNotEmpty) 'firstName': firstName!.trim(),
      if ((lastName ?? '').trim().isNotEmpty) 'lastName': lastName!.trim(),
      if ((companyName ?? '').trim().isNotEmpty)
        'companyName': companyName!.trim(),
    };

    try {
      final res = await _dio.postUri(
        routes.otpVerify(),
        data: payload,
        options: _skipAuth,
      );

      final out = OtpVerifyApiResult.fromJson(_asJsonMap(res.data));
      if (!out.ok) throw StateError('OTP verify failed.');
      return out;
    } on DioException catch (ex) {
      _failDio('verifyOtpRaw', ex);
    }
  }

  // ─────────────────────────────────────────────
  // Session
  // ─────────────────────────────────────────────

  Future<AuthUser> loadSession() async {
    try {
      final res = await _dio.getUri(routes.getCurrentUser());

      final map = _asJsonMap(res.data);
      if (map.isEmpty) {
        final fallback = jsonDecode(jsonEncode(res.data));
        if (fallback is Map) {
          final user = AuthUser.fromMap(Map<String, dynamic>.from(fallback));
          _cachedUser = user;
          return user;
        }
        throw StateError('Invalid session payload: expected an object.');
      }

      final user = AuthUser.fromMap(map);
      _cachedUser = user;
      return user;
    } on DioException catch (ex) {
      _failDio('loadSession', ex);
    }
  }

  bool get isSignedIn => _auth.currentUser != null;

  Future<void> logOut() async {
    await _auth.signOut();
    _cachedUser = null;
  }

  Future<AuthUser> saveProfile({
    required String firstName,
    required String lastName,
    String? companyName,
  }) async {
    final fn = _requireTrimmed(firstName, 'First name is required');
    final ln = _requireTrimmed(lastName, 'Last name is required');
    final cn = (companyName ?? '').trim();

    final uid = fb.FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) throw StateError('Not signed in — missing uid.');

    final payload = <String, dynamic>{
      // IMPORTANT: backend PATCH /auth_users strict schema currently does NOT accept
      // firstName/lastName unless you've added them to PatchAuthUserSchema.
      //
      // If you *did* add them on backend, keep these.
      'firstName': fn,
      'lastName': ln,
      if (cn.isNotEmpty) 'companyName': cn,
    };

    try {
      final res = await _dio.patchUri(routes.updateUser(uid), data: payload);

      // ✅ unwrap `{ user: {...} }` and inject uid if missing
      final userMap = _ensureUid(_unwrapUserMap(res.data), uid);

      final user = AuthUser.fromMap(userMap);
      _cachedUser = user;

      // ✅ refresh canonical session so AuthGate releases immediately
      try {
        await loadSession();
      } catch (_) {
        // ignore: we already have a usable user
      }

      return _cachedUser ?? user;
    } on DioException catch (ex) {
      _failDio('saveProfile', ex);
    }
  }

  // ─────────────────────────────────────────────
  // ✅ Sign in with custom token (Firebase)
  // ─────────────────────────────────────────────

  Future<fb.UserCredential> signInWithCustomToken(String customToken) async {
    final token = _requireTrimmed(customToken, 'customToken is required');

    final cred = await _auth.signInWithCustomToken(token);

    // Best-effort refresh so subsequent calls have a valid ID token.
    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (_) {
      // ignore
    }

    // Refresh tenant session
    await loadSession();

    return cred;
  }

  // ─────────────────────────────────────────────
  // ✅ Convenience: verify + sign in (tenant-scoped)
  // ─────────────────────────────────────────────

  Future<OtpVerifyApiResult> verifyOtpAndSignIn({
    required String attemptId,
    required String code,
    String? firstName,
    String? lastName,
    String? companyName,
  }) async {
    final out = await verifyOtpRaw(
      attemptId: attemptId,
      code: code,
      firstName: firstName,
      lastName: lastName,
      companyName: companyName,
    );

    final token = (out.customToken ?? '').trim();
    if (token.isEmpty) {
      throw StateError('Missing customToken from otp/verify response.');
    }

    await signInWithCustomToken(token);
    return out;
  }

  JsonMap _unwrapUserMap(Object? data) {
    final root = _asJsonMap(data);
    if (root.isEmpty) return const <String, dynamic>{};

    final userObj = root['user'];
    if (userObj is Map) return Map<String, dynamic>.from(userObj);

    return root; // already a user map
  }

  JsonMap _ensureUid(JsonMap userMap, String uid) {
    final existing = userMap['uid'];
    if (existing is String && existing.trim().isNotEmpty) return userMap;

    final out = Map<String, dynamic>.from(userMap);
    out['uid'] = uid;
    return out;
  }
}
