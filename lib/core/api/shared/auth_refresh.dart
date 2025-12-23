// lib/core/api/shared/auth_refresh.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Coalesces concurrent refresh requests into one inflight call.
class TokenRefresher {
  Future<String?>? _inflight;

  Future<String?> refreshOnce({Duration timeout = const Duration(seconds: 8)}) {
    final inflight = _inflight;
    if (inflight != null) return inflight;

    final fut = _run(timeout);
    _inflight = fut;
    return fut;
  }

  Future<String?> _run(Duration timeout) async {
    try {
      final u = fb.FirebaseAuth.instance.currentUser;
      if (u == null) return null;

      // Force-refresh token to pick up newly minted custom claims.
      return await u.getIdToken(true).timeout(timeout);
    } catch (_) {
      return null;
    } finally {
      _inflight = null;
    }
  }
}
