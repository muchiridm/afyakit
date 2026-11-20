import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'document_model.dart';
import 'documents_service.dart';

/// Each query has isolated state; the service reacts to active app/tenant changes.
typedef DocumentsQuery = ({String profileId, int page, bool isActive});
const documentsPageSize = 50;

final documentsControllerProvider = FutureProvider.autoDispose
    .family<List<Document>, DocumentsQuery>((ref, query) async {
      final service = await ref.watch(documentsServiceProvider.future);
      return service.list(
        profileId: query.profileId,
        page: query.page,
        perPage: documentsPageSize,
        isActive: query.isActive,
      );
    });
