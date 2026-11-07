import 'package:afyakit/features/records/campaigns/models/campaign.dart';
import 'package:afyakit/features/records/campaigns/services/campaigns_service.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/native_contacts_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final campaignsProvider = FutureProvider.autoDispose<List<Campaign>>((ref) async {
  final service = await ref.watch(campaignsServiceProvider.future);
  // Full campaign listing, bounded to avoid silently losing campaigns after page 1.
  final all = <Campaign>[];
  for (var page = 1; page <= 100; page++) {
    final results = await service.list(page: page);
    all.addAll(results);
    if (results.length < 50) break;
  }
  return all;
});

final campaignOrganisationsProvider = FutureProvider.autoDispose<List<NativeContact>>((ref) async {
  final service = await ref.watch(nativeContactsServiceProvider.future);
  final all = <NativeContact>[];
  for (var page = 1; page <= 100; page++) {
    final contacts = await service.list(page: page, perPage: 100);
    all.addAll(contacts.where((contact) => contact.isOrganization));
    if (contacts.length < 100) break;
  }
  all.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  return all;
});

final campaignQuestionnairesProvider = FutureProvider.autoDispose<List<QuestionnaireTemplateSummary>>((ref) async {
  final service = await ref.watch(campaignsServiceProvider.future);
  return service.templates();
});
