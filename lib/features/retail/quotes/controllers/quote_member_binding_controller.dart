// lib/features/retail/quotes/controllers/quote_member_binding_controller.dart

import 'dart:async';

import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/providers/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/contacts/services/zoho_contacts_service.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final quoteMemberBindingControllerProvider =
    Provider<QuoteMemberBindingController>(
      (Ref ref) => QuoteMemberBindingController(ref),
    );

class QuoteMemberBindingController {
  QuoteMemberBindingController(this._ref);

  final Ref _ref;

  Future<void>? _inFlight;
  String? _bindKey;

  QuoteMetaController get _metaCtl =>
      _ref.read(quoteMetaControllerProvider.notifier);

  QuoteMetaState get _meta => _ref.read(quoteMetaControllerProvider);

  Future<ZohoContact?> resolve({bool showError = false}) async {
    final QuoteContactPolicy policy = _ref.read(quoteContactPolicyProvider);
    if (policy != QuoteContactPolicy.memberScoped) return null;

    final ZohoMemberCustomerScope? scope = _ref.read(
      zohoMemberCustomerScopeProvider,
    );

    final String accountNumber = (scope?.accountNumber ?? '').trim();
    final String contactId = (scope?.contactId ?? '').trim();

    _debug(
      'scope accountNumber=$accountNumber '
      'contactId=$contactId '
      'scope=${scope?.debugLabel ?? 'null'}',
    );

    if (accountNumber.isEmpty) {
      if (showError) SnackService.showError('Missing account scope.');
      return null;
    }

    final ZohoContact? current = _currentValidContact(
      accountNumber: accountNumber,
      contactId: contactId,
    );

    if (current != null) return current;

    final String nextBindKey = _buildBindKey(
      accountNumber: accountNumber,
      contactId: contactId,
    );

    final Future<void>? active = _inFlight;
    if (active != null && _bindKey == nextBindKey) {
      _debug('reusing in-flight bind $nextBindKey');
      await active;

      return _currentValidContact(
        accountNumber: accountNumber,
        contactId: contactId,
      );
    }

    late final Future<void> future;

    future =
        _resolveAndStore(
          accountNumber: accountNumber,
          contactId: contactId,
          showError: showError,
        ).whenComplete(() {
          if (identical(_inFlight, future)) {
            _inFlight = null;
            _bindKey = null;
          }
        });

    _bindKey = nextBindKey;
    _inFlight = future;

    await future;

    return _currentValidContact(
      accountNumber: accountNumber,
      contactId: contactId,
    );
  }

  Future<void> _resolveAndStore({
    required String accountNumber,
    required String contactId,
    required bool showError,
  }) async {
    try {
      final ZohoContactsService service = await _ref.read(
        zohoContactsServiceProvider.future,
      );

      final ZohoContact? resolved = await _resolveContact(
        service: service,
        accountNumber: accountNumber,
        contactId: contactId,
        showError: showError,
      );

      if (resolved == null) return;

      if (!_contactMatchesAccount(resolved, accountNumber)) {
        if (showError) {
          SnackService.showError(
            'Customer profile does not match your account.',
          );
        }

        _debug(
          'final account mismatch expected=$accountNumber '
          'actual=${resolved.accountNumber ?? ''}',
        );

        return;
      }

      final ZohoContact? current = _currentValidContact(
        accountNumber: accountNumber,
        contactId: contactId,
      );

      if (current != null) return;

      _metaCtl.setContact(resolved);

      _debug(
        'bound customer contactId=${resolved.contactId} '
        'accountNumber=${resolved.accountNumber ?? ''} '
        'title=${resolved.title}',
      );
    } catch (e, st) {
      _debug('failed: $e');
      if (kDebugMode) debugPrint('$st');

      if (showError) {
        SnackService.showError('Failed to resolve customer profile.');
      }
    }
  }

  Future<ZohoContact?> _resolveContact({
    required ZohoContactsService service,
    required String accountNumber,
    required String contactId,
    required bool showError,
  }) async {
    if (contactId.isNotEmpty) {
      final ZohoContact? optimistic = _localMemberContact(
        accountNumber: accountNumber,
        contactId: contactId,
      );

      if (optimistic != null) {
        unawaited(
          refreshInBackground(
            contactId: contactId,
            accountNumber: accountNumber,
          ),
        );

        return optimistic;
      }

      final ZohoContact? byId = await _loadByContactId(
        service: service,
        contactId: contactId,
        accountNumber: accountNumber,
        showError: showError,
      );

      if (byId != null) return byId;
    }

    _debug('fallback GET by accountNumber=$accountNumber');

    final ZohoContact? byAccount = await service.getByAccountNumber(
      accountNumber,
      type: ZohoContactTypeFilter.customerOnly,
    );

    if (byAccount == null) {
      if (showError) {
        SnackService.showError('Your customer profile is missing.');
      }
      _debug('no customer profile found');
    }

    return byAccount;
  }

  ZohoContact? _localMemberContact({
    required String accountNumber,
    required String contactId,
  }) {
    final ZohoContact? local = _ref.read(currentMemberZohoContactProvider);
    if (local == null) return null;

    final String localAccount = (local.accountNumber ?? '').trim();
    final String localContactId = local.contactId.trim();

    if (localContactId != contactId || localAccount != accountNumber) {
      return null;
    }

    _debug(
      'optimistic local bind contactId=${local.contactId} '
      'accountNumber=${local.accountNumber ?? ''} '
      'title=${local.title}',
    );

    return local;
  }

  Future<ZohoContact?> _loadByContactId({
    required ZohoContactsService service,
    required String contactId,
    required String accountNumber,
    required bool showError,
  }) async {
    _debug('fast path LIGHT GET contactId=$contactId');

    final ZohoContact contact = await service.getLight(contactId);

    final String actualId = contact.contactId.trim();
    final String actualAccount = (contact.accountNumber ?? '').trim();

    _debug(
      'fast path light result contactId=$actualId '
      'accountNumber=$actualAccount '
      'title=${contact.title}',
    );

    if (actualId != contactId) {
      if (showError) {
        SnackService.showError('Customer profile link is invalid.');
      }

      _debug(
        'fast path rejected expected contactId=$contactId actual=$actualId',
      );

      return null;
    }

    if (actualAccount.isNotEmpty && actualAccount != accountNumber) {
      if (showError) {
        SnackService.showError('Customer profile does not match your account.');
      }

      _debug(
        'fast path rejected expected account=$accountNumber '
        'actual=$actualAccount',
      );

      return null;
    }

    return contact;
  }

  Future<void> refreshInBackground({
    required String contactId,
    required String accountNumber,
  }) async {
    final String id = contactId.trim();
    final String account = accountNumber.trim();

    if (id.isEmpty || account.isEmpty) return;

    try {
      final ZohoContactsService service = await _ref.read(
        zohoContactsServiceProvider.future,
      );

      final ZohoContact fresh = await service.getLight(id);

      if (fresh.contactId.trim() != id) return;
      if (!_contactMatchesAccount(fresh, account)) return;

      final ZohoContact? current = _currentValidContact(
        accountNumber: account,
        contactId: id,
      );

      if (current == null) return;

      _metaCtl.setContact(fresh);

      _debug(
        'background refresh patched contactId=${fresh.contactId} '
        'accountNumber=${fresh.accountNumber ?? ''} '
        'title=${fresh.title}',
      );
    } catch (e) {
      _debug('background refresh failed: $e');
    }
  }

  ZohoContact? _currentValidContact({
    required String accountNumber,
    required String contactId,
  }) {
    final ZohoContact? current = _meta.contact;
    if (current == null) return null;

    final String currentAccount = (current.accountNumber ?? '').trim();
    final String currentContactId = current.contactId.trim();

    if (contactId.isNotEmpty && currentContactId == contactId) {
      _debug('already bound by contactId=$contactId');
      return current;
    }

    if (currentAccount == accountNumber) {
      _debug('already bound by accountNumber=$accountNumber');
      return current;
    }

    return null;
  }

  bool _contactMatchesAccount(ZohoContact contact, String accountNumber) {
    final String actual = (contact.accountNumber ?? '').trim();
    final String expected = accountNumber.trim();

    return actual.isEmpty || actual == expected;
  }

  String _buildBindKey({
    required String accountNumber,
    required String contactId,
  }) {
    final String account = accountNumber.trim();
    final String contact = contactId.trim();

    return contact.isNotEmpty ? 'id:$contact' : 'acct:$account';
  }

  void _debug(String message) {
    if (!kDebugMode) return;
    debugPrint('[QuoteMemberBinding] $message');
  }
}
