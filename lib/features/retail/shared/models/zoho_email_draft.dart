import 'package:flutter/foundation.dart';
import 'package:afyakit/shared/utils/utils.dart';

@immutable
class ZohoEmailDraft {
  const ZohoEmailDraft({
    this.to = const <String>[],
    this.cc = const <String>[],
    this.bcc = const <String>[],
    this.contactPersonIds = const <String>[],
    this.subject,
    this.body,
    this.fromOrgEmailId,
  });

  final List<String> to;
  final List<String> cc;
  final List<String> bcc;

  /// If you have Zoho contact_person_id(s), prefer these.
  final List<String> contactPersonIds;

  final String? subject;
  final String? body;

  /// Zoho sometimes requires this.
  final String? fromOrgEmailId;

  // ───────────────────────── Sanitizers ─────────────────────────

  static List<String> _cleanList(List<String> xs) {
    final seen = <String>{};
    final out = <String>[];

    for (final raw in xs) {
      final t = readStringOrNull(raw);
      if (t == null) continue;
      if (seen.add(t)) out.add(t);
    }

    return out;
  }

  /// Extract email from formats like:
  /// - "Name <email@domain.com>"
  /// - "<email@domain.com>"
  static String _stripAngleEmail(String v) {
    final s = readString(v);
    final lt = s.indexOf('<');
    final gt = s.lastIndexOf('>');
    if (lt >= 0 && gt > lt) {
      final inner = s.substring(lt + 1, gt).trim();
      return inner.isEmpty ? s : inner;
    }
    return s;
  }

  /// Split combined input like:
  /// - "a@b.com, c@d.com"
  /// - "a@b.com; c@d.com"
  static Iterable<String> _splitMulti(String v) sync* {
    final s = readString(v);
    if (s.isEmpty) return;

    // Common separators from chips/textfield paste.
    final parts = s.split(RegExp(r'[;,]'));
    for (final p in parts) {
      final t = readStringOrNull(p);
      if (t != null) yield t;
    }
  }

  // Pragmatic email regex:
  // - requires local@domain.tld
  // - forbids spaces
  // - forbids consecutive dots in domain
  static final RegExp _emailRe = RegExp(
    r"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$",
    caseSensitive: false,
  );

  static bool _looksValidEmail(String v) {
    final s = readString(v);
    if (s.isEmpty) return false;
    if (s.contains(' ')) return false;
    if (!_emailRe.hasMatch(s)) return false;

    // Extra guard: reject obvious bad domains like "a@b..com"
    final at = s.indexOf('@');
    if (at <= 0 || at == s.length - 1) return false;
    final domain = s.substring(at + 1);
    if (domain.contains('..')) return false;

    return true;
  }

  static List<String> _cleanEmails(List<String> xs) {
    final seen = <String>{};
    final out = <String>[];

    for (final raw in xs) {
      final src = readStringOrNull(raw);
      if (src == null) continue;

      // Split pasted lists and sanitize each token.
      for (final token in _splitMulti(src)) {
        final maybe = _stripAngleEmail(token);
        if (!_looksValidEmail(maybe)) continue;

        // Normalize to lower-case to avoid duplicates
        final normalized = maybe.trim().toLowerCase();
        if (normalized.isEmpty) continue;

        if (seen.add(normalized)) out.add(normalized);
      }
    }

    return out;
  }

  bool get hasAnyRecipient =>
      _cleanEmails(to).isNotEmpty || _cleanList(contactPersonIds).isNotEmpty;

  Map<String, Object?> toJson() {
    final toClean = _cleanEmails(to);
    final ccClean = _cleanEmails(cc);
    final bccClean = _cleanEmails(bcc);
    final cpClean = _cleanList(contactPersonIds);

    final subjectClean = readStringOrNull(subject);
    final bodyClean = readStringOrNull(body);
    final fromIdClean = readStringOrNull(fromOrgEmailId);

    return <String, Object?>{
      // Only include fields if they are actually valid & non-empty
      if (toClean.isNotEmpty) 'to_mail_ids': toClean,
      if (ccClean.isNotEmpty) 'cc_mail_ids': ccClean,
      if (bccClean.isNotEmpty) 'bcc_mail_ids': bccClean,
      if (cpClean.isNotEmpty) 'contact_person_ids': cpClean,
      if (subjectClean != null) 'subject': subjectClean,
      if (bodyClean != null) 'body': bodyClean,
      if (fromIdClean != null) 'send_from_org_email_id': fromIdClean,
    };
  }
}
