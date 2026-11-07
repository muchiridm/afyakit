import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/records/campaigns/models/campaign.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final campaignsServiceProvider = FutureProvider<CampaignsService>((ref) async =>
    CampaignsService(
      await ref.watch(afyakitClientFutureProvider.future),
      ref.watch(afyakitRoutesProvider),
    ));

class CampaignsService {
  const CampaignsService(this.api, this.routes);
  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  static Map<String, Object?> _map(Object? raw) {
    if (raw is Map) return Map<String, Object?>.from(raw);
    throw const FormatException('Unexpected campaign API response');
  }

  static Campaign _campaign(Object? raw) => Campaign.fromJson(_map(raw));

  Future<List<Campaign>> list({int page = 1, bool includeArchived = false}) async {
    final result = await api.getUri<Object?>(routes.recordsCampaignsList(
      page: page, includeArchived: includeArchived,
    ));
    final items = _map(result.data)['campaigns'];
    if (items is! List) throw const FormatException('Missing campaigns array');
    return items.map(_campaign).toList(growable: false);
  }

  Future<Campaign> get(String id) async {
    final result = await api.getUri<Object?>(routes.recordsCampaignGet(id));
    return _campaign(_map(result.data)['campaign']);
  }

  Future<Campaign> create(CampaignDraft draft) async {
    final result = await api.postUri<Object?>(routes.recordsCampaignCreate(), data: draft.toJson());
    return _campaign(_map(result.data)['campaign']);
  }

  Future<Campaign> setStatus(String id, String status) async {
    final result = await api.postUri<Object?>(routes.recordsCampaignSetStatus(id),
      data: <String, Object?>{'status': status});
    return _campaign(_map(result.data)['campaign']);
  }

  Future<List<QuestionnaireTemplateSummary>> templates() async {
    final result = await api.getUri<Object?>(routes.recordsQuestionnaireTemplatesList());
    final items = _map(result.data)['templates'];
    if (items is! List) throw const FormatException('Missing questionnaire templates');
    return items.map((e) => QuestionnaireTemplateSummary.fromJson(_map(e)))
        .toList(growable: false);
  }
}
