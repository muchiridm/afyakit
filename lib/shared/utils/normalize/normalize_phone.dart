import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

String normalizePhone(String input) {
  try {
    final parsed = PhoneNumber.parse(
      input,
      callerCountry: IsoCode.KE, // 👈 This replaces `isoCode: 'KE'`
    );
    return parsed.international; // e.g. +254712345678
  } catch (e) {
    debugPrint('❌ Failed to normalize phone: $e');
    return input.trim(); // fallback raw
  }
}

String? normalizeMpesaPhoneKE(String? input) {
  final raw = (input ?? '').trim();
  if (raw.isEmpty) return null;

  try {
    final parsed = PhoneNumber.parse(raw, callerCountry: IsoCode.KE);
    final intl = parsed.international; // e.g. +2547..., +2541...
    final digits = intl.startsWith('+') ? intl.substring(1) : intl;

    // ✅ Safaricom M-Pesa lines: 07xx and 011x (=> 2547... or 2541...)
    if (RegExp(r'^254(7|1)\d{8}$').hasMatch(digits)) {
      return digits;
    }

    debugPrint('❌ Not a valid KE mobile for M-Pesa: $digits');
    return null;
  } catch (e) {
    debugPrint('❌ Failed to normalize phone: $e');
    return null;
  }
}
