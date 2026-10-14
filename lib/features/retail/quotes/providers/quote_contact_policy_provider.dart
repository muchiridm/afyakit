// lib/features/retail/quotes/providers/quote_contact_policy_provider.dart

import 'package:afyakit/features/home/enums/entry_mode.dart';
import 'package:afyakit/features/home/providers/entry_mode_providers.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final quoteContactPolicyProvider = Provider<QuoteContactPolicy>((ref) {
  final mode = ref.watch(effectiveEntryModeProvider);

  return mode == EntryMode.member
      ? QuoteContactPolicy.memberScoped
      : QuoteContactPolicy.picker;
});
