import 'package:dio/dio.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'inventory_issue.dart';

class InventoryIssuesService {
  const InventoryIssuesService({required this.dio, required this.routes, required this.appId});
  final Dio dio;
  final AfyaKitRoutes routes;
  final String appId;
  Options get _options => Options(headers: {'x-app-id': appId});
  Uri get _base => routes.issues();
  Uri _at(String id, [String? action]) => _base.replace(pathSegments: [
    ..._base.pathSegments.where((p) => p.isNotEmpty), id, if (action != null) action,
  ]);
  Map<String, dynamic> _object(dynamic value) {
    if (value is! Map) throw const FormatException('Expected JSON object');
    return Map<String, dynamic>.from(value);
  }

  Future<InventoryIssuePage> list({int page = 1, int perPage = 50,
    InventoryIssueType? type, InventoryIssueStatus? status}) async {
    final query = <String, String>{'page': '$page', 'per_page': '$perPage',
      if (type != null) 'issue_type': type.name, if (status != null) 'status': status.name};
    final data = _object((await dio.getUri(_base.replace(queryParameters: query), options: _options)).data);
    return InventoryIssuePage(
      issues: (data['issues'] as List? ?? const []).map((e) => InventoryIssue.fromJson(_object(e))).toList(),
      page: (data['page'] as num?)?.toInt() ?? page,
      hasMore: data['has_more'] == true,
    );
  }

  Future<List<InventoryIssue>> listAll({InventoryIssueType? type, InventoryIssueStatus? status}) async {
    final result = <InventoryIssue>[];
    for (var page = 1; ; page++) {
      final part = await list(page: page, type: type, status: status);
      result.addAll(part.issues);
      if (!part.hasMore) return result;
    }
  }

  Future<InventoryIssue> get(String id) async =>
      InventoryIssue.fromJson(_object((await dio.getUri(_at(id), options: _options)).data));

  Future<InventoryIssue> create(InventoryIssueDraft draft) async {
    draft.validate();
    return InventoryIssue.fromJson(_object((await dio.postUri(_base,
      data: draft.toJson(), options: _options)).data));
  }

  Future<InventoryIssue> action(String id, String action) async {
    if (!const {'approve', 'reject', 'cancel', 'issue', 'receive'}.contains(action)) {
      throw ArgumentError.value(action, 'action', 'Unsupported issue action');
    }
    final data = _object((await dio.postUri(_at(id, action), options: _options)).data);
    return InventoryIssue.fromJson(_object(data['record']));
  }
}
