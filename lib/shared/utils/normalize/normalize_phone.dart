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
