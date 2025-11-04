import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class TokenRefresher {
  Future<String?> Function()? _inflight;

  Future<String?> refreshOnce() {
    final existing = _inflight;
    if (existing != null) return existing();

    Future<String?> run() async {
      try {
        final u = fb.FirebaseAuth.instance.currentUser;
        if (u == null) return null;
        return await u.getIdToken(true).timeout(const Duration(seconds: 8));
      } catch (_) {
        return null;
      } finally {
        _inflight = null;
      }
    }

    final f = run;
    _inflight = f;
    return f();
  }
}
