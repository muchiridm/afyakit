// lib/features/retail/invoices/widgets/invoice_detail_permissions.dart

import 'package:afyakit/core/workspace/providers/workspace_mode_provider.dart';
import 'package:afyakit/features/retail/invoices/models/zoho_invoice.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class InvoiceUiPermissions {
  const InvoiceUiPermissions({
    required this.canViewPdf,
    required this.canSend,
    required this.canMarkSent,
    required this.canRecordPayment,
    required this.isDraft,
    required this.isSent,
    required this.isPaid,
    required this.isVoid,
    required this.hasBalance,
    required this.isStaffWorkspaceActive,
  });

  final bool canViewPdf;
  final bool canSend;
  final bool canMarkSent;
  final bool canRecordPayment;

  final bool isDraft;
  final bool isSent;
  final bool isPaid;
  final bool isVoid;
  final bool hasBalance;

  final bool isStaffWorkspaceActive;
}

InvoiceUiPermissions buildInvoiceUiPermissions(
  WidgetRef ref,
  ZohoInvoice invoice, {
  bool? forceStaffWorkspace,
}) {
  final bool providerSaysStaff = ref.watch(isStaffWorkspaceActiveProvider);
  final bool isStaffWorkspaceActive = forceStaffWorkspace ?? providerSaysStaff;

  final String status = invoice.status.trim().toLowerCase();

  final bool isDraft = status.isEmpty || status == 'draft';
  final bool isSent = status == 'sent';
  final bool isPaid = status == 'paid';
  final bool isVoid = status == 'void' || status == 'voided';

  final num? balance = invoice.balance;
  final bool hasBalance = balance != null && balance.isFinite && balance > 0;

  /*
   * Staff workspace:
   * Staff can operate Zoho invoices.
   *
   * Member workspace:
   * Members can view invoice content and PDF, but cannot send,
   * mark sent, or record payments.
   */
  final bool staffCanSend = isStaffWorkspaceActive && !isPaid && !isVoid;

  final bool staffCanMarkSent =
      isStaffWorkspaceActive && isDraft && !isPaid && !isVoid;

  final bool staffCanRecordPayment =
      isStaffWorkspaceActive && hasBalance && !isVoid;

  return InvoiceUiPermissions(
    canViewPdf: invoice.invoiceId.trim().isNotEmpty,
    canSend: staffCanSend,
    canMarkSent: staffCanMarkSent,
    canRecordPayment: staffCanRecordPayment,
    isDraft: isDraft,
    isSent: isSent,
    isPaid: isPaid,
    isVoid: isVoid,
    hasBalance: hasBalance,
    isStaffWorkspaceActive: isStaffWorkspaceActive,
  );
}
