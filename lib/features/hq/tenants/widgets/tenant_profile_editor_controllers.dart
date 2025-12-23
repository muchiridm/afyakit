import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:flutter/material.dart';

final class TenantProfileFormControllers {
  TenantProfileFormControllers({
    required this.displayName,
    required this.website,
    required this.email,
    required this.whatsapp,
    required this.registrationNumber,
    required this.mmName,
    required this.mmAccount,
    required this.mmNumber,
  });

  final TextEditingController displayName;

  // public / contact
  final TextEditingController website;
  final TextEditingController email;
  final TextEditingController whatsapp;
  final TextEditingController registrationNumber;

  // mobile money
  final TextEditingController mmName;
  final TextEditingController mmAccount;
  final TextEditingController mmNumber;

  factory TenantProfileFormControllers.fromTenant(TenantProfile? p) {
    final payments = p?.details.payments ?? const <String, dynamic>{};

    return TenantProfileFormControllers(
      displayName: TextEditingController(text: p?.displayName ?? ''),
      website: TextEditingController(text: p?.details.website ?? ''),
      email: TextEditingController(text: p?.details.email ?? ''),
      whatsapp: TextEditingController(text: p?.details.whatsapp ?? ''),
      registrationNumber: TextEditingController(
        text:
            (p?.details.compliance['registrationNumber'] as String?) ??
            (p?.details.compliance['regNumber'] as String?) ??
            '',
      ),
      mmName: TextEditingController(
        text: payments['mobileMoneyName'] as String? ?? '',
      ),
      mmAccount: TextEditingController(
        text: payments['mobileMoneyAccount'] as String? ?? '',
      ),
      mmNumber: TextEditingController(
        text: payments['mobileMoneyNumber'] as String? ?? '',
      ),
    );
  }

  void dispose() {
    displayName.dispose();
    website.dispose();
    email.dispose();
    whatsapp.dispose();
    registrationNumber.dispose();
    mmName.dispose();
    mmAccount.dispose();
    mmNumber.dispose();
  }
}
