// lib/features/retail/quotes/widgets/quote_detail_permissions.dart

import 'package:afyakit/core/workspace/providers/workspace_mode_provider.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuoteUiPermissions {
  const QuoteUiPermissions({
    required this.canViewPdf,
    required this.canEdit,
    required this.canDelete,
    required this.canSend,
    required this.canMarkSent,
    required this.canConvertToInvoice,
    required this.isDraft,
    required this.isStaffWorkspaceActive,
  });

  final bool canViewPdf;
  final bool canEdit;
  final bool canDelete;
  final bool canSend;
  final bool canMarkSent;
  final bool canConvertToInvoice;
  final bool isDraft;
  final bool isStaffWorkspaceActive;
}

QuoteUiPermissions buildQuoteUiPermissions(
  WidgetRef ref,
  ZohoQuote quote, {
  bool? forceStaffWorkspace,
}) {
  final bool providerSaysStaff = ref.watch(isStaffWorkspaceActiveProvider);
  final bool isStaffWorkspaceActive = forceStaffWorkspace ?? providerSaysStaff;

  final String status = quote.status.trim().toLowerCase();

  final bool isDraft = status.isEmpty || status == 'draft';
  final bool isSent = status == 'sent';
  final bool isAccepted = status == 'accepted';

  final bool isClosed =
      status == 'declined' ||
      status == 'expired' ||
      status == 'converted' ||
      status == 'invoiced';

  /*
   * Staff workspace:
   * Staff can operate Zoho quotes.
   *
   * Member workspace:
   * Members can edit/delete their own draft quote requests,
   * but cannot send, mark sent, convert, or view Zoho PDF actions.
   */
  final bool staffCanEdit = isStaffWorkspaceActive && isDraft;
  final bool staffCanDelete = isStaffWorkspaceActive && isDraft;
  final bool staffCanSend = isStaffWorkspaceActive && isDraft;
  final bool staffCanMarkSent = isStaffWorkspaceActive && isDraft;

  final bool staffCanConvertToInvoice =
      isStaffWorkspaceActive && !isDraft && !isClosed && (isSent || isAccepted);

  final bool memberCanEdit = !isStaffWorkspaceActive && isDraft;
  final bool memberCanDelete = !isStaffWorkspaceActive && isDraft;

  return QuoteUiPermissions(
    canViewPdf: isStaffWorkspaceActive,
    canEdit: staffCanEdit || memberCanEdit,
    canDelete: staffCanDelete || memberCanDelete,
    canSend: staffCanSend,
    canMarkSent: staffCanMarkSent,
    canConvertToInvoice: staffCanConvertToInvoice,
    isDraft: isDraft,
    isStaffWorkspaceActive: isStaffWorkspaceActive,
  );
}
