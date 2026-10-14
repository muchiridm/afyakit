// lib/features/retail/quotes/controllers/quote_member_binding_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/retail/contacts/providers/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/contacts/services/zoho_contacts_service.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';
import 'package:afyakit/shared/services/snack_service.dart';

final quoteMemberBindingControllerProvider =
    Provider<QuoteMemberBindingController>(
      (ref) => QuoteMemberBindingController(ref),
    );

class QuoteMemberBindingController {
  QuoteMemberBindingController(this._ref);
  final Ref _ref;

  Future<String?>? _inFlight;
  String? _inFlightNativeId;

  Future<String?> resolve({bool showError = false}) async {
    if (_ref.read(quoteContactPolicyProvider) !=
        QuoteContactPolicy.memberScoped) {
      return null;
    }
    final nativeId = (_ref.read(currentMemberNativeContactIdProvider) ?? '')
        .trim();
    if (nativeId.isEmpty) {
      if (showError)
        SnackService.showError('Your account has no linked Native Contact.');
      return null;
    }
    final current = _ref.read(quoteMetaControllerProvider);
    if (current.nativeContactId == nativeId &&
        (current.zohoContactId ?? '').trim().isNotEmpty) {
      return current.zohoContactId;
    }
    if (_inFlightNativeId == nativeId && _inFlight != null) {
      return _inFlight;
    }
    final task = _lookup(nativeId, showError: showError);
    _inFlightNativeId = nativeId;
    _inFlight = task;
    try {
      return await task;
    } finally {
      if (identical(_inFlight, task)) {
        _inFlight = null;
        _inFlightNativeId = null;
      }
    }
  }

  Future<String?> _lookup(String nativeId, {required bool showError}) async {
    try {
      final service = await _ref.read(zohoContactsServiceProvider.future);
      final ZohoMappedContact mapped = await service.getMappedContact(nativeId);
      if (mapped.nativeContactId.trim() != nativeId ||
          mapped.zohoContactId.trim().isEmpty) {
        throw StateError('The customer mapping is invalid');
      }
      // Reject a stale request, for instance after switching accounts.
      if ((_ref.read(currentMemberNativeContactIdProvider) ?? '').trim() !=
              nativeId ||
          _ref.read(quoteContactPolicyProvider) !=
              QuoteContactPolicy.memberScoped ||
          _ref.read(quoteMetaControllerProvider).isInsurancePayment) {
        return null;
      }
      _ref
          .read(quoteMetaControllerProvider.notifier)
          .setVerifiedCustomerMapping(
            nativeContactId: nativeId,
            zohoContactId: mapped.zohoContactId,
            customerName: mapped.contactName,
          );
      return mapped.zohoContactId.trim();
    } catch (error) {
      if (showError)
        SnackService.showError(
          'Could not resolve your accounting customer profile: $error',
        );
      return null;
    }
  }
}
