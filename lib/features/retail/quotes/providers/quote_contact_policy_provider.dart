// lib/features/retail/quotes/providers/quote_contact_policy_provider.dart

import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/providers/entry_mode_providers.dart';
import 'package:afyakit/features/retail/contacts/providers/zoho_contacts_account_scope_provider.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final quoteContactPolicyProvider = Provider<QuoteContactPolicy>((ref) {
  final mode = ref.watch(effectiveEntryModeProvider);
  final acct = (ref.watch(zohoContactsAccountScopeProvider) ?? '').trim();

  final isMemberScoped = mode == EntryMode.member && acct.isNotEmpty;
  return isMemberScoped
      ? QuoteContactPolicy.memberScoped
      : QuoteContactPolicy.picker;
});
