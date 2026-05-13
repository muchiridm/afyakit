// lib/features/retail/quotes/widgets/quote_editor_screen.dart

import 'package:afyakit/core/auth/auth_user/guards/require_auth.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_state.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';
import 'package:afyakit/features/retail/shared/sales_doc/dialogs.dart';
import 'package:afyakit/features/retail/shared/sales_doc/feedback.dart';
import 'package:afyakit/features/retail/shared/sales_doc/header.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quote_editor_actions.dart';
import 'quote_editor_lines_section.dart';
import 'quote_editor_meta_section.dart';

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

  final TextEditingController _refCtl = TextEditingController();
  final TextEditingController _notesCtl = TextEditingController();

  ProviderSubscription<QuoteMetaState>? _metaSub;

  bool get _isEdit => (widget.editingQuoteId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _bindMetaTextControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didUpdateWidget(covariant QuoteEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final String oldId = (oldWidget.editingQuoteId ?? '').trim();
    final String newId = (widget.editingQuoteId ?? '').trim();

    if (oldId == newId) return;

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _metaSub?.close();
    _refCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  void _bindMetaTextControllers() {
    _metaSub = ref.listenManual<QuoteMetaState>(quoteMetaControllerProvider, (
      QuoteMetaState? prev,
      QuoteMetaState next,
    ) {
      final bool didRefChange = prev?.reference != next.reference;
      final bool didNotesChange = prev?.customerNotes != next.customerNotes;

      if (!didRefChange && !didNotesChange) return;

      final String nextRef = next.reference ?? '';
      final String nextNotes = next.customerNotes ?? '';

      if (_refCtl.text != nextRef) _refCtl.text = nextRef;
      if (_notesCtl.text != nextNotes) _notesCtl.text = nextNotes;
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;

    final QuoteMetaController metaCtl = ref.read(
      quoteMetaControllerProvider.notifier,
    );

    final String id = (widget.editingQuoteId ?? '').trim();

    if (id.isNotEmpty) {
      metaCtl.beginEdit(id);
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

  Future<bool> _handleBack(BuildContext context, QuoteState s) async {
    if (s.busy) return false;

    final bool hasLines = ref
        .read(quoteLinesControllerProvider)
        .lines
        .isNotEmpty;

    final QuoteMetaState meta = ref.read(quoteMetaControllerProvider);

    final bool hasMetaEdits =
        (meta.reference ?? '').trim().isNotEmpty ||
        (meta.customerNotes ?? '').trim().isNotEmpty ||
        meta.contact != null ||
        meta.quoteDate != null ||
        meta.expiryDate != null ||
        meta.deliveryAddress != null;

    if (!hasLines && !hasMetaEdits) return true;

    final bool ok = _isEdit
        ? await SalesDocDialogs.confirmDiscardChanges(context)
        : await SalesDocDialogs.confirmDiscardCheckout(context);

    if (!ok) return false;

    await _clearAll();
    return true;
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

  @override
  Widget build(BuildContext context) {
    final QuoteState s = ref.watch(quoteControllerProvider);
    final QuoteController ctl = ref.read(quoteControllerProvider.notifier);

    final QuoteMetaState meta = ref.watch(quoteMetaControllerProvider);
    final QuoteMetaController metaCtl = ref.read(
      quoteMetaControllerProvider.notifier,
    );

    final QuoteLinesState linesState = ref.watch(quoteLinesControllerProvider);

    final QuoteContactPolicy policy = ref.watch(quoteContactPolicyProvider);
    final bool isMemberScoped = policy == QuoteContactPolicy.memberScoped;

    final String fallbackPartyName = isMemberScoped
        ? ((meta.contact?.title ?? '').trim().isNotEmpty
              ? meta.contact!.title
              : 'Loading customer…')
        : 'Customer';

    final SalesDocMetaVm vmMeta = buildQuoteMetaVm(
      meta: meta,
      linesState: linesState,
      isEdit: _isEdit,
      requirePrices: widget.requirePrices,
      fallbackPartyName: fallbackPartyName,
    );

    return WillPopScope(
      onWillPop: () => _handleBack(context, s),
      child: AppPage(
        title: _isEdit ? 'Edit quote' : 'Request a quote',
        showBack: true,
        maxWidth: _contentMaxW,
        scrollable: false,
        actions: const <Widget>[],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (s.busy) const LinearProgressIndicator(minHeight: 2),
            ErrorBanner(s.error),
            SalesDocHeader(
              title: 'Quote',
              meta: vmMeta,
              compact: true,
              showDocNumber: _isEdit,
              showDate: false,
              showStatus: false,
              trailing: QuoteEditorHeaderActions(
                isEdit: _isEdit,
                busy: s.busy,
                meta: meta,
                vmMeta: vmMeta,
                isMemberScoped: isMemberScoped,
                onContactPicked: metaCtl.setContact,
                onDelete: () => _handleDeleteQuote(context, ctl, meta),
                onEnsureAuthed: () => _ensureAuthed(context),
              ),
            ),
            QuoteEditorMetaSection(
              busy: s.busy,
              meta: meta,
              metaCtl: metaCtl,
              refController: _refCtl,
              notesController: _notesCtl,
              onEnsureAuthed: () => _ensureAuthed(context),
            ),
            const Divider(height: 1),
            Expanded(
              child: QuoteEditorLinesSection(
                busy: s.busy,
                linesState: linesState,
                requirePrices: widget.requirePrices,
                isMemberScoped: isMemberScoped,
                currencyCode: quoteCurrencyCode(),
              ),
            ),
            QuoteEditorFooterBar(
              busy: s.busy,
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
