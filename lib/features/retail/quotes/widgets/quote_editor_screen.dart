// lib/features/retail/quotes/widgets/quote_editor_screen.dart

import 'package:afyakit/core/auth/auth_user/guards/require_auth.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/states/quote_meta_state.dart';
import 'package:afyakit/features/retail/quotes/controllers/states/quote_state.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';
import 'package:afyakit/features/retail/shared/sales_doc/dialogs.dart';
import 'package:afyakit/features/retail/shared/sales_doc/feedback.dart';
import 'package:afyakit/features/retail/shared/sales_doc/header.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quote_details_summary.dart';
import 'quote_editor_actions.dart';
import 'quote_editor_details_sheet.dart';
import 'quote_editor_lines_section.dart';

enum QuoteEditorResult { saved, deleted }

class QuoteEditorScreen extends ConsumerStatefulWidget {
  const QuoteEditorScreen({
    super.key,
    this.editingQuoteId,
    this.requirePrices = true,
  });

  final String? editingQuoteId;
  final bool requirePrices;

  @override
  ConsumerState<QuoteEditorScreen> createState() => _QuoteEditorScreenState();
}

class _QuoteEditorScreenState extends ConsumerState<QuoteEditorScreen> {
  static const double _contentMaxW = 980;

  String get _editingId => (widget.editingQuoteId ?? '').trim();

  bool get _isEdit => _editingId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didUpdateWidget(covariant QuoteEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final String oldId = (oldWidget.editingQuoteId ?? '').trim();
    final String newId = _editingId;

    if (oldId == newId) return;

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;

    final String id = _editingId;

    if (id.isNotEmpty) {
      ref.read(quoteMetaControllerProvider.notifier).beginEdit(id);
    }

    final QuoteController ctl = ref.read(quoteControllerProvider.notifier);

    await ctl.ensureReady(
      editingQuoteId: widget.editingQuoteId,
      requirePrices: widget.requirePrices,
    );
  }

  void _clearQuoteLines() {
    ref.read(quoteLinesControllerProvider.notifier).clear();
  }

  Future<void> _clearAll() async {
    _clearQuoteLines();
    ref.read(quoteMetaControllerProvider.notifier).clearAll();
    ref.read(quoteControllerProvider.notifier).reset();
  }

  Future<bool> _ensureAuthed(BuildContext context) {
    return requireAuth(context, ref);
  }

  bool _hasMetaEdits(QuoteMetaState meta) {
    return (meta.reference ?? '').trim().isNotEmpty ||
        (meta.customerNotes ?? '').trim().isNotEmpty ||
        meta.contact != null ||
        meta.quoteDate != null ||
        meta.expiryDate != null ||
        meta.deliveryAddress != null ||
        meta.patientSnapshot != null ||
        (meta.resolvedPatientId ?? '').trim().isNotEmpty ||
        (meta.resolvedMembershipId ?? '').trim().isNotEmpty ||
        (meta.resolvedPrescriptionId ?? '').trim().isNotEmpty;
  }

  bool _hasDraftEdits(QuoteLinesState linesState, QuoteMetaState meta) {
    return linesState.isNotEmpty || _hasMetaEdits(meta);
  }

  Future<bool> _handleBack(BuildContext context, QuoteState state) async {
    if (state.busy) return false;

    if (!_isEdit) {
      return true;
    }

    final bool ok = await SalesDocDialogs.confirmDiscardChanges(context);
    if (!ok) return false;

    await _clearAll();
    return true;
  }

  Future<void> _handleDiscardQuote(BuildContext context) async {
    final QuoteLinesState linesState = ref.read(quoteLinesControllerProvider);
    final QuoteMetaState meta = ref.read(quoteMetaControllerProvider);

    if (!_hasDraftEdits(linesState, meta)) {
      await _clearAll();

      if (!context.mounted) return;
      Navigator.of(context).maybePop();
      return;
    }

    final bool ok = await SalesDocDialogs.confirmDiscardCheckout(context);
    if (!ok) return;

    await _clearAll();

    if (!context.mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _handleDeleteQuote(
    BuildContext context,
    QuoteController ctl,
    QuoteMetaState meta,
  ) async {
    final bool ok = await SalesDocDialogs.confirmDelete(
      context,
      thing: 'quote',
      message: 'This will delete the quote in Zoho Books.',
    );

    if (!ok) return;

    final String id = (meta.editingQuoteId ?? '').trim();
    if (id.isEmpty) return;

    final bool done = await ctl.deleteQuote(id);
    if (!done) return;
    if (!context.mounted) return;

    await _clearAll();

    if (!context.mounted) return;
    Navigator.of(context).pop(QuoteEditorResult.deleted);
  }

  Future<void> _handleSubmit(BuildContext context, QuoteController ctl) async {
    final bool ok = await _ensureAuthed(context);
    if (!ok) return;

    final String? id = await ctl.submit(requirePrices: widget.requirePrices);
    if (id == null || id.trim().isEmpty) return;
    if (!context.mounted) return;

    await _clearAll();

    if (!context.mounted) return;
    Navigator.of(context).pop(QuoteEditorResult.saved);
  }

  Future<void> _openQuoteDetails(
    BuildContext context, {
    required QuoteMetaState meta,
    required QuoteMetaController metaCtl,
    required String tenantId,
  }) async {
    final QuoteContactPolicy policy = ref.read(quoteContactPolicyProvider);

    final bool isStaffMode = policy == QuoteContactPolicy.picker;

    final QuoteMetaState? result = await QuoteEditorDetailsSheet.open(
      context,
      initial: meta,
      tenantId: tenantId,
      isStaffMode: isStaffMode,
      onEnsureAuthed: () => _ensureAuthed(context),
    );

    if (result == null || !context.mounted) return;

    metaCtl.applyState(result);
  }

  bool _editIsHydrating(QuoteState state) {
    final String id = _editingId;
    if (id.isEmpty) return false;

    final String loadedId = (state.loadedEditId ?? '').trim();
    if (loadedId == id) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final String tenantId = ref.watch(tenantIdProvider);

    final QuoteState state = ref.watch(quoteControllerProvider);
    final QuoteController ctl = ref.read(quoteControllerProvider.notifier);

    final QuoteMetaState meta = ref.watch(quoteMetaControllerProvider);
    final QuoteMetaController metaCtl = ref.read(
      quoteMetaControllerProvider.notifier,
    );

    final QuoteLinesState linesState = ref.watch(quoteLinesControllerProvider);

    final QuoteContactPolicy policy = ref.watch(quoteContactPolicyProvider);
    final bool isMemberScoped = policy == QuoteContactPolicy.memberScoped;

    final bool editIsHydrating = _editIsHydrating(state);
    final bool showDiscardDraft = !_isEdit && _hasDraftEdits(linesState, meta);

    final String fallbackPartyName = isMemberScoped
        ? ((meta.contact?.title ?? '').trim().isNotEmpty
              ? meta.contact!.title
              : 'Loading customer…')
        : (_isEdit ? 'Loading customer…' : 'Customer');

    final SalesDocMetaVm vmMeta = buildQuoteMetaVm(
      meta: meta,
      linesState: linesState,
      isEdit: _isEdit,
      requirePrices: widget.requirePrices,
      fallbackPartyName: fallbackPartyName,
    );

    return WillPopScope(
      onWillPop: () => _handleBack(context, state),
      child: AppPage(
        title: _isEdit ? 'Edit quote' : 'Request a quote',
        showBack: true,
        maxWidth: _contentMaxW,
        scrollable: false,
        actions: const <Widget>[],
        body: editIsHydrating
            ? _QuoteEditLoadingState(error: state.error)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (state.busy) const LinearProgressIndicator(minHeight: 2),
                  ErrorBanner(state.error),
                  SalesDocHeader(
                    title: 'Quote',
                    meta: vmMeta,
                    compact: true,
                    showDocNumber: _isEdit,
                    showDate: false,
                    showStatus: false,
                    trailing: QuoteEditorHeaderActions(
                      isEdit: _isEdit,
                      busy: state.busy,
                      meta: meta,
                      vmMeta: vmMeta,
                      isMemberScoped: isMemberScoped,
                      onContactPicked: metaCtl.setContact,
                      onDelete: () => _handleDeleteQuote(context, ctl, meta),
                      onEnsureAuthed: () => _ensureAuthed(context),
                    ),
                  ),
                  QuoteDetailsSummary(
                    meta: meta,
                    busy: state.busy,
                    onTap: () => _openQuoteDetails(
                      context,
                      meta: meta,
                      metaCtl: metaCtl,
                      tenantId: tenantId,
                    ),
                  ),
                  Expanded(
                    child: QuoteEditorLinesSection(
                      busy: state.busy,
                      linesState: linesState,
                      requirePrices: widget.requirePrices,
                      isMemberScoped: isMemberScoped,
                      currencyCode: quoteCurrencyCode(),
                    ),
                  ),
                  if (showDiscardDraft)
                    _DiscardQuoteBar(
                      busy: state.busy,
                      onDiscard: () => _handleDiscardQuote(context),
                    ),
                  QuoteEditorFooterBar(
                    busy: state.busy,
                    isEdit: _isEdit,
                    meta: meta,
                    linesState: linesState,
                    requirePrices: widget.requirePrices,
                    isMemberScoped: isMemberScoped,
                    currencyCode: vmMeta.currencyCode,
                    onEnsureAuthed: () => _ensureAuthed(context),
                    onSubmit: () => _handleSubmit(context, ctl),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DiscardQuoteBar extends StatelessWidget {
  const _DiscardQuoteBar({required this.busy, required this.onDiscard});

  final bool busy;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: busy ? null : onDiscard,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Discard quote'),
            style: TextButton.styleFrom(foregroundColor: colors.error),
          ),
        ),
      ),
    );
  }
}

class _QuoteEditLoadingState extends StatelessWidget {
  const _QuoteEditLoadingState({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LinearProgressIndicator(minHeight: 2),
        ErrorBanner(error),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading quote details…',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please wait while we fetch the customer, patient, insurance membership, prescription, delivery address and quote items.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String quoteCurrencyCode() => 'KES';

SalesDocMetaVm buildQuoteMetaVm({
  required QuoteMetaState meta,
  required QuoteLinesState linesState,
  required bool isEdit,
  required bool requirePrices,
  required String fallbackPartyName,
}) {
  final String contactTitle = _clean(meta.contact?.title) ?? '';
  final String fallback = _clean(fallbackPartyName) ?? '';

  final String partyName = contactTitle.isNotEmpty
      ? contactTitle
      : fallback.isNotEmpty
      ? fallback
      : 'Customer';

  final String editingId = _clean(meta.editingQuoteId) ?? '';

  return SalesDocMetaVm(
    partyName: partyName,
    docNumberOrId: isEdit
        ? editingId.isEmpty
              ? '-'
              : editingId
        : '',
    status: isEdit ? 'editing' : 'draft',
    currencyCode: quoteCurrencyCode(),
    total: requirePrices ? linesState.estimatedTotal : 0,
    date: meta.quoteDate,
    expiryDate: meta.expiryDate,
  );
}

String? _clean(String? value) {
  final String text = (value ?? '').trim();
  return text.isEmpty ? null : text;
}
