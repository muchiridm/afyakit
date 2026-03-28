// lib/core/auth/auth_session/services/auth_service.dart

import 'dart:convert';

import 'package:afyakit/core/auth/auth_session/models/auth_api_exception.dart';
import 'package:afyakit/shared/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
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

enum OtpNextStep { collectEmail, collectName, recoverAccount, done }

OtpNextStep _parseNextStep(String? s) {
  switch ((s ?? '').trim()) {
    case 'collect_email':
      return OtpNextStep.collectEmail;
    case 'collect_name':
      return OtpNextStep.collectName;
    case 'recover_account':
      return OtpNextStep.recoverAccount;
    default:
      return OtpNextStep.done;
  }
}

OtpNextStep _nextFromUser(AuthUser u) {
  if (u.recoveryRequired) {
    return OtpNextStep.recoverAccount;
  }

  if (!u.emailVerified || (u.emailLower ?? '').trim().isEmpty) {
    return OtpNextStep.collectEmail;
  }

  final dn = (u.displayName ?? '').trim();
  if (dn.isEmpty) return OtpNextStep.collectName;

  if (u.isCompany) {
    final cn = (u.companyName ?? '').trim();
    if (cn.isEmpty) return OtpNextStep.collectName;
  } else {
    final fn = (u.firstName ?? '').trim();
    final ln = (u.lastName ?? '').trim();
    if (fn.isEmpty || ln.isEmpty) return OtpNextStep.collectName;
  }

  return OtpNextStep.done;
}

class OtpVerifyApiResult {
  const OtpVerifyApiResult({
    required this.ok,
    required this.customToken,
    required this.uid,
    required this.tenant,
    required this.next,
    required this.recoveryRequired,
  });

  final bool ok;
  final String? customToken;
  final String? uid;
  final String? tenant;
  final OtpNextStep next;
  final bool recoveryRequired;

  static String? _readTrimmedString(Object? v) {
    final s = v is String ? v.trim() : null;
    return (s == null || s.isEmpty) ? null : s;
  }

  factory OtpVerifyApiResult.fromJson(JsonMap j) {
    final ok = j['ok'] == true || j['success'] == true;

    final recovery = j['recoveryRequired'] == true;

    return OtpVerifyApiResult(
      ok: ok,
      customToken: _readTrimmedString(j['customToken']),
      uid: _readTrimmedString(j['uid']),
      tenant: _readTrimmedString(j['tenant'] ?? j['tenantId']),
      next: recovery
          ? OtpNextStep.recoverAccount
          : _parseNextStep(_readTrimmedString(j['next'])),
      recoveryRequired: recovery,
    );
  }
}

/// Result of token-gated membership handshake after Firebase login.
/// (This is a LOCAL result shape for the app; backend doesn't have to return it.)
class CheckStatusResult {
  const CheckStatusResult({
    required this.ok,
    required this.next,
    required this.user,
    required this.recoveryRequired,
  });

  final bool ok;
  final OtpNextStep next;
  final AuthUser user;
  final bool recoveryRequired;
}

class SubmitRecoveryResult {
  const SubmitRecoveryResult({
    required this.ok,
    required this.next,
    required this.user,
    required this.recoveryRequired,
  });

  final bool ok;
  final OtpNextStep next;
  final AuthUser user;
  final bool recoveryRequired;
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

  static bool _acceptStatusUnder500(int? s) => s != null && s < 500;

  // ─────────────────────────────────────────────
  // Debug logging
  // ─────────────────────────────────────────────

  void _log(String msg) {
    if (!kDebugMode) return;
    debugPrint('🔐 [AuthService:$tenantId] $msg');
  }

  void _logReq({
    required String op,
    required Uri uri,
    required Object? data,
    required Options? options,
  }) {
    if (!kDebugMode) return;

    final headers = options?.headers ?? const <String, dynamic>{};
    final hasAuth =
        (headers['Authorization'] is String) &&
        (headers['Authorization'] as String).trim().isNotEmpty;

    final extra = options?.extra ?? const <String, dynamic>{};
    final skipAuth = extra['skipAuth'] == true;

    String safeBody;
    try {
      safeBody = jsonEncode(data);
    } catch (_) {
      safeBody = '$data';
    }

    _log('$op → $uri');
    _log('  skipAuth=$skipAuth, hasAuthHeader=$hasAuth');
    _log('  body=$safeBody');
  }

  void _logResp(String op, Response<dynamic> res) {
    if (!kDebugMode) return;
    _log('$op ✓ HTTP ${res.statusCode}');
    final err = _readErrorMessage(res.data);
    if (err != null) _log('  serverError=$err');
  }

  void _logErr(String op, DioException e) {
    if (!kDebugMode) return;
    final status = e.response?.statusCode;
    final err = _readErrorMessage(e.response?.data);
    _log(
      '$op ✕ ${status != null ? 'HTTP $status' : 'HTTP ?'}'
      '${err != null ? ' · $err' : ''}',
    );
  }

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

  String? _readErrorMessage(Object? body) {
    final m = _asJsonMap(body);
    if (m.isEmpty) return null;

    final err = m['error'];
    if (err is String && err.trim().isNotEmpty) return err.trim();

    final msg = m['message'];
    if (msg is String && msg.trim().isNotEmpty) return msg.trim();

    return null;
  }

  String _opError(String op, DioException e) {
    final status = e.response?.statusCode;
    final err = _readErrorMessage(e.response?.data);

    final parts = <String>[
      op,
      if (status != null) 'HTTP $status',
      if (err != null) err,
    ];

    return parts.join(' · ');
  }

  Never _failDio(String op, DioException e) {
    _logErr(op, e);
    throw StateError(_opError(op, e));
  }

  StartResponse _parseStartResponse(Object? data) {
    return StartResponse.fromJson(_asJsonMap(data));
  }

  static String _requireTrimmed(String value, String message) {
    final v = value.trim();
    if (v.isEmpty) throw ArgumentError(message);
    return v;
  }

  static void _ensureAttemptId(StartResponse out, String message) {
    if (out.throttled == true) return;
    if (out.ok != true) return;

    // ✅ Firebase SMS client flow does NOT return attemptId
    if (out.requiresFirebaseSmsClientAction) return;

    if (out.hasAttempt) return;

    throw StateError(message);
  }

  /// Always returns an Authorization header with a FRESH token.
  Future<Options> _authHeaderFresh() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) {
      throw StateError('Not signed in · missing Firebase user');
    }

    final token = (await fbUser.getIdToken(true))?.trim() ?? '';
    if (token.isEmpty) {
      throw StateError('Not signed in · missing Firebase idToken');
    }

    return Options(
      headers: <String, dynamic>{'Authorization': 'Bearer $token'},
      extra: const <String, dynamic>{
        'skipAuth': false,
        'forceFreshToken': true,
        'preserveAuthHeader': true,
      },
    );
  }

  // ─────────────────────────────────────────────
  // PUBLIC: start phone entry (AUTO)
  // ─────────────────────────────────────────────

  Future<StartResponse> startAutoOtp(
    String phoneInput, {
    int codeLength = 6,
  }) async {
    final phone = _requireTrimmed(phoneInput, 'Phone number is required');

    final uri = routes.autoStart();
    final body = <String, dynamic>{
      'phoneNumber': phone,
      'codeLength': codeLength,
    };

    final opts = Options(
      extra: _skipAuth.extra,
      validateStatus: _acceptStatusUnder500,
    );

    try {
      _logReq(op: 'startAutoOtp', uri: uri, data: body, options: opts);

      final res = await _dio.postUri(uri, data: body, options: opts);

      _logResp('startAutoOtp', res);

      final out = _parseStartResponse(res.data);

      // ✅ If backend says EMAIL_REQUIRED (expected 400), DO NOT throw.
      if (res.statusCode == 400 && out.requiresCollectEmail) {
        return out;
      }

      // Any other 4xx from this endpoint is not expected control flow.
      if ((res.statusCode ?? 0) >= 400) {
        final err = _readErrorMessage(res.data) ?? 'bad-request';
        throw StateError('startAutoOtp · HTTP ${res.statusCode} · $err');
      }

      _ensureAttemptId(
        out,
        'OTP start returned ok=true but no attemptId was returned (and not firebase_sms).',
      );

      return out;
    } on DioException catch (e) {
      _failDio('startAutoOtp', e);
    }
  }

  // ─────────────────────────────────────────────
  // PUBLIC: backend OTP verify (EMAIL attempt only)
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

    final uri = routes.otpVerify();
    final payload = <String, dynamic>{
      'attemptId': a,
      'code': c,
      if ((firstName ?? '').trim().isNotEmpty) 'firstName': firstName!.trim(),
      if ((lastName ?? '').trim().isNotEmpty) 'lastName': lastName!.trim(),
      if ((companyName ?? '').trim().isNotEmpty)
        'companyName': companyName!.trim(),
    };

    try {
      _logReq(op: 'verifyOtpRaw', uri: uri, data: payload, options: _skipAuth);

      final res = await _dio.postUri(uri, data: payload, options: _skipAuth);

      _logResp('verifyOtpRaw', res);

      final out = OtpVerifyApiResult.fromJson(_asJsonMap(res.data));
      if (!out.ok) throw StateError('OTP verify failed');
      return out;
    } on DioException catch (ex) {
      _failDio('verifyOtpRaw', ex);
    }
  }

  // ─────────────────────────────────────────────
  // AUTH REQUIRED: OTP verify for verify-email flow
  // ─────────────────────────────────────────────

  Future<OtpVerifyApiResult> verifyEmailOtpAuthed({
    required String attemptId,
    required String code,
  }) async {
    final a = _requireTrimmed(attemptId, 'attemptId is required');
    final c = _requireTrimmed(code, 'code is required');

    final authed = await _authHeaderFresh();
    final uri = routes.otpVerify();

    final payload = <String, dynamic>{'attemptId': a, 'code': c};

    try {
      _logReq(
        op: 'verifyEmailOtpAuthed',
        uri: uri,
        data: payload,
        options: authed,
      );

      final res = await _dio.postUri(uri, data: payload, options: authed);

      _logResp('verifyEmailOtpAuthed', res);

      final out = OtpVerifyApiResult.fromJson(_asJsonMap(res.data));
      if (!out.ok) throw StateError('OTP verify failed');
      return out;
    } on DioException catch (ex) {
      _failDio('verifyEmailOtpAuthed', ex);
    }
  }

  // ─────────────────────────────────────────────
  // AUTH REQUIRED: verify-email start
  // ─────────────────────────────────────────────

  Future<StartResponse> startVerifyEmailOtp({
    required String email,
    int codeLength = 6,
  }) async {
    final e = _requireTrimmed(email, 'Email is required');
    final authed = await _authHeaderFresh();

    final uri = routes.emailStart();
    final body = <String, Object?>{
      'email': e,
      'codeLength': codeLength,
      'purpose': 'verify_email',
    };

    try {
      _logReq(op: 'startVerifyEmailOtp', uri: uri, data: body, options: authed);

      final res = await _dio.postUri(uri, data: body, options: authed);

      _logResp('startVerifyEmailOtp', res);

      final out = _parseStartResponse(res.data);
      final sc = res.statusCode ?? 0;

      if (sc >= 400) {
        final serverCode =
            (_readErrorMessage(res.data) ?? out.code ?? 'bad-request')
                .trim()
                .toUpperCase();

        throw AuthApiException(
          statusCode: sc,
          code: serverCode,
          userMessage: friendlyAuthMessage(
            status: sc,
            code: serverCode,
            email: e,
          ),
          debugMessage: 'POST $uri · HTTP $sc · $serverCode',
        );
      }

      if (out.throttled != true && out.ok == true && !out.hasAttempt) {
        throw AuthApiException(
          statusCode: 500,
          code: 'MISSING_ATTEMPT_ID',
          userMessage: 'Could not start email verification. Please try again.',
          debugMessage: 'Verify-email OTP start ok but attemptId missing',
        );
      }

      return out;
    } on DioException catch (ex) {
      _failDio('startVerifyEmailOtp', ex);
    }
  }

  Future<StartResponse> startEmailLoginOtp({
    required String email,
    required String phoneNumber,
    int codeLength = 6,
  }) async {
    final e = _requireTrimmed(email, 'Email is required');
    final p = _requireTrimmed(phoneNumber, 'Phone number is required');

    final uri = routes.emailStart();
    final body = <String, Object?>{
      'email': e,
      'phoneNumber': p,
      'codeLength': codeLength,
      'purpose': 'login',
    };

    final opts = Options(
      extra: _skipAuth.extra,
      validateStatus: _acceptStatusUnder500,
    );

    try {
      _logReq(op: 'startEmailLoginOtp', uri: uri, data: body, options: opts);

      final res = await _dio.postUri(uri, data: body, options: opts);

      _logResp('startEmailLoginOtp', res);

      final out = _parseStartResponse(res.data);
      final sc = res.statusCode ?? 0;

      if (sc >= 400) {
        final serverCode =
            (_readErrorMessage(res.data) ?? out.code ?? 'BAD_REQUEST')
                .trim()
                .toUpperCase();

        throw AuthApiException(
          statusCode: sc,
          code: serverCode,
          userMessage: friendlyAuthMessage(
            status: sc,
            code: serverCode,
            email: e,
            phone: p,
          ),
          debugMessage: 'POST $uri · HTTP $sc · $serverCode',
        );
      }

      if (out.throttled != true && out.ok == true && !out.hasAttempt) {
        throw AuthApiException(
          statusCode: 500,
          code: 'MISSING_ATTEMPT_ID',
          userMessage: 'Could not start email login. Please try again.',
          debugMessage: 'Email OTP start ok but attemptId missing',
        );
      }

      return out;
    } on DioException catch (e) {
      _failDio('startEmailLoginOtp', e);
    }
  }

  // ─────────────────────────────────────────────
  // AUTH REQUIRED: membership handshake (after Firebase login)
  //
  // ✅ Backend-aligned: we use /auth/session/sync-claims as the handshake.
  // This is exactly the “refresh session” endpoint in your backend.
  //
  // Then we load /auth/session/me as canonical session user and compute next.
  // ─────────────────────────────────────────────

  Future<CheckStatusResult> checkUserStatusAfterFirebaseLogin() async {
    final uri = routes.syncClaims();
    final authed = await _authHeaderFresh();

    try {
      _logReq(op: 'syncClaims', uri: uri, data: const {}, options: authed);

      final res = await _dio.postUri(
        uri,
        data: const <String, dynamic>{},
        options: authed,
      );

      _logResp('syncClaims', res);

      final syncMap = _asJsonMap(res.data);
      final syncRecoveryRequired = syncMap['recoveryRequired'] == true;

      final user = await loadSession();
      final recoveryRequired = syncRecoveryRequired || user.recoveryRequired;

      final next = recoveryRequired
          ? OtpNextStep.recoverAccount
          : _nextFromUser(user);

      return CheckStatusResult(
        ok: true,
        next: next,
        user: user,
        recoveryRequired: recoveryRequired,
      );
    } on DioException catch (ex) {
      _failDio('syncClaims', ex);
    }
  }

  Future<SubmitRecoveryResult> submitRecoveryAccountNumber({
    required String accountNumber,
  }) async {
    final acc = _requireTrimmed(accountNumber, 'Account number is required');
    final authed = await _authHeaderFresh();

    final uri = routes.sessionRecoverAccount();
    final payload = <String, dynamic>{'recoverFromAccountNumber': acc};

    try {
      _logReq(
        op: 'submitRecoveryAccountNumber',
        uri: uri,
        data: payload,
        options: authed,
      );

      final res = await _dio.postUri(uri, data: payload, options: authed);

      _logResp('submitRecoveryAccountNumber', res);

      final user = await loadSession();
      final recoveryRequired = user.recoveryRequired == true;
      final next = recoveryRequired
          ? OtpNextStep.recoverAccount
          : _nextFromUser(user);

      return SubmitRecoveryResult(
        ok: true,
        next: next,
        user: user,
        recoveryRequired: recoveryRequired,
      );
    } on DioException catch (ex) {
      _failDio('submitRecoveryAccountNumber', ex);
    }
  }

  // ─────────────────────────────────────────────
  // Session (AUTH REQUIRED, ALWAYS)
  // ─────────────────────────────────────────────

  Future<AuthUser> loadSession() async {
    final uri = routes.getCurrentUser();

    try {
      final authed = await _authHeaderFresh();

      _logReq(op: 'loadSession', uri: uri, data: null, options: authed);

      final res = await _dio.getUri(uri, options: authed);

      _logResp('loadSession', res);

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

  // ─────────────────────────────────────────────
  // Profile save (AUTH REQUIRED)
  // ─────────────────────────────────────────────

  Future<AuthUser> saveProfile({
    required String firstName,
    required String lastName,
    required String displayName,
    String? companyName,
  }) async {
    final fn = _requireTrimmed(firstName, 'First name is required');
    final ln = _requireTrimmed(lastName, 'Last name is required');
    final dn = _requireTrimmed(displayName, 'Display name is required');
    final cn = (companyName ?? '').trim();

    final uid = fb.FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) throw StateError('Not signed in — missing uid.');

    final uri = routes.updateUser(uid);
    final payload = <String, dynamic>{
      'firstName': fn,
      'lastName': ln,
      'displayName': dn,
      if (cn.isNotEmpty) 'companyName': cn,
    };

    try {
      final authed = await _authHeaderFresh();

      _logReq(op: 'saveProfile', uri: uri, data: payload, options: authed);

      final res = await _dio.patchUri(uri, data: payload, options: authed);

      _logResp('saveProfile', res);

      final userMap = _ensureUid(_unwrapUserMap(res.data), uid);
      final user = AuthUser.fromMap(userMap);
      _cachedUser = user;

      try {
        await loadSession();
      } catch (_) {
        // ignore
      }

      return _cachedUser ?? user;
    } on DioException catch (ex) {
      _failDio('saveProfile', ex);
    }
  }

  // ─────────────────────────────────────────────
  // Sign in with custom token (Firebase)
  // ─────────────────────────────────────────────

  Future<fb.UserCredential> signInWithCustomToken(String customToken) async {
    final token = _requireTrimmed(customToken, 'customToken is required');

    final cred = await _auth.signInWithCustomToken(token);

    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (_) {
      // ignore
    }

    await loadSession();
    return cred;
  }

  // ─────────────────────────────────────────────
  // Convenience: backend verify + sign in
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

  // ─────────────────────────────────────────────
  // Small response helpers
  // ─────────────────────────────────────────────

  JsonMap _unwrapUserMap(Object? data) {
    final root = _asJsonMap(data);
    if (root.isEmpty) return const <String, dynamic>{};

    final userObj = root['user'];
    if (userObj is Map) return Map<String, dynamic>.from(userObj);

    return root;
  }

  JsonMap _ensureUid(JsonMap userMap, String uid) {
    final existing = userMap['uid'];
    if (existing is String && existing.trim().isNotEmpty) return userMap;

    final out = Map<String, dynamic>.from(userMap);
    out['uid'] = uid;
    return out;
  }
}
