// lib/features/retail/sales/quotes/widgets/quote_editor_screen.dart

import 'package:afyakit/core/auth/auth_user/guards/require_auth.dart';
import 'package:afyakit/features/retail/catalog/controllers/cart_controller.dart';
import 'package:afyakit/features/retail/shared/models/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/widgets/contact_picker_dialog.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_state.dart';

import 'package:afyakit/features/retail/shared/widgets/sales_doc_dialogs.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_doc_feedback.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_doc_header.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_doc_lines.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_doc_models.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_doc_status_chip.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_doc_total_bar.dart';

import 'package:afyakit/shared/layout/app_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  static const double _contentMaxW = 720;
  static const double _kTrailH = 36;

  final _refCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  ProviderSubscription<QuoteState>? _draftSub;

  bool get _isEdit => (widget.editingQuoteId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _bindDraftTextControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didUpdateWidget(covariant QuoteEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldId = (oldWidget.editingQuoteId ?? '').trim();
    final newId = (widget.editingQuoteId ?? '').trim();
    if (oldId == newId) return;

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _draftSub?.close();
    _refCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  void _bindDraftTextControllers() {
    _draftSub = ref.listenManual<QuoteState>(quoteControllerProvider, (
      prev,
      next,
    ) {
      final didLoadChange = prev?.loadedEditId != next.loadedEditId;
      final didDraftChange = prev?.draft != next.draft;
      if (!didLoadChange && !didDraftChange) return;

      final nextRef = next.draft.reference ?? '';
      final nextNotes = next.draft.customerNotes ?? '';

      if (_refCtl.text != nextRef) _refCtl.text = nextRef;
      if (_notesCtl.text != nextNotes) _notesCtl.text = nextNotes;
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final ctl = ref.read(quoteControllerProvider.notifier);
    await ctl.ensureReady(
      editingQuoteId: widget.editingQuoteId,
      requirePrices: widget.requirePrices,
    );
  }

  void _clearCatalogCart() => ref.read(cartControllerProvider.notifier).clear();

  Future<void> _clearAll(QuoteController ctl) async {
    _clearCatalogCart();
    ctl.reset();
  }

  Future<bool> _ensureAuthed(BuildContext context) => requireAuth(context, ref);

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  String _currencyCodeFromState(QuoteState s) => 'KES';

  Future<bool> _handleBack(
    BuildContext context,
    QuoteState s,
    QuoteController ctl,
  ) async {
    if (s.busy) return false;

    final hasDraftLines = s.draft.lines.isNotEmpty;
    final hasCartLines = ref.read(cartControllerProvider).lines.isNotEmpty;
    if (!hasDraftLines && !hasCartLines) return true;

    final ok = _isEdit
        ? await SalesDocDialogs.confirmDiscardChanges(context)
        : await SalesDocDialogs.confirmDiscardCheckout(context);
    if (!ok) return false;

    await _clearAll(ctl);
    if (_isEdit) ctl.cancelEdit();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(quoteControllerProvider);
    final ctl = ref.read(quoteControllerProvider.notifier);

    return WillPopScope(
      onWillPop: () => _handleBack(context, s, ctl),
      child: AppPage(
        title: _isEdit ? 'Edit quote' : 'Request a quote',
        showBack: true,
        maxWidth: _contentMaxW,
        scrollable: false,
        actions: _buildTopActions(context, s, ctl),
        body: _buildBody(context, s, ctl),
      ),
    );
  }

  List<Widget> _buildTopActions(
    BuildContext context,
    QuoteState s,
    QuoteController ctl,
  ) {
    final theme = Theme.of(context);

    final hasDraftLines = s.draft.lines.isNotEmpty;
    final hasCartLines = ref.watch(cartControllerProvider).lines.isNotEmpty;
    final canClear = !s.busy && (hasDraftLines || hasCartLines);

    return [
      PopupMenuButton<_AddAction>(
        tooltip: 'Add',
        enabled: !s.busy,
        onSelected: (a) => _handleAddAction(context, a, s, ctl),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _AddAction.addCustomLine,
            child: Text('Add custom item'),
          ),
          PopupMenuItem(
            value: _AddAction.goToCatalog,
            child: Text('Add from catalog'),
          ),
        ],
        icon: const Icon(Icons.add),
      ),

      if (_isEdit)
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
          ),
          onPressed: s.busy
              ? null
              : () async {
                  final ok = await SalesDocDialogs.confirmDiscardChanges(
                    context,
                  );
                  if (!ok) return;

                  _clearCatalogCart();
                  ctl.cancelEdit();
                  if (!context.mounted) return;
                  Navigator.of(context).pop(false);
                },
          child: const Text('Cancel'),
        ),

      IconButton(
        tooltip: 'Clear',
        icon: const Icon(Icons.delete_outline),
        style: IconButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: canClear
            ? () async {
                final ok = await SalesDocDialogs.confirmClearAll(context);
                if (!ok) return;

                await _clearAll(ctl);
                if (!context.mounted) return;
                _toast(context, 'Cleared');
              }
            : null,
      ),
    ];
  }

  Future<void> _handleAddAction(
    BuildContext context,
    _AddAction action,
    QuoteState s,
    QuoteController ctl,
  ) async {
    if (s.busy) return;

    switch (action) {
      case _AddAction.goToCatalog:
        _toast(context, 'Open catalog from your existing flow.');
        return;

      case _AddAction.addCustomLine:
        final ok = await _ensureAuthed(context);
        if (!ok) return;

        final name = await SalesDocDialogs.editText(
          context,
          title: 'Custom item name',
          initial: '',
        );
        if (name == null) return;

        ctl.addCustomLine(name: name);
        return;
    }
  }

  SalesDocMetaVm _metaVm(QuoteState s) {
    final contactTitle = (s.draft.contact?.title ?? '').trim();
    final partyName = contactTitle.isNotEmpty
        ? contactTitle
        : (s.draft.displayContactName.trim().isNotEmpty
              ? s.draft.displayContactName.trim()
              : 'Customer');

    final docNo = _isEdit
        ? ((s.editingQuoteId ?? '').trim().isEmpty
              ? '-'
              : (s.editingQuoteId ?? '').trim())
        : 'Draft';

    return SalesDocMetaVm(
      partyName: partyName,
      docNumberOrId: docNo,
      status: _isEdit ? 'editing' : 'draft',
      currencyCode: _currencyCodeFromState(s),
      total: widget.requirePrices ? s.total : 0,
      date: s.quoteDate,
    );
  }

  List<SalesDocLineVm> _lineVms(QuoteState s) {
    return s.draft.lines
        .map((line) {
          final tile = line.tile;

          final desc = (line.description ?? '').trim();
          final tileTitle = tile.tileTitle.trim();
          final tileDesc = (tile.tileDesc ?? '').trim();

          final isGeneric = desc.isEmpty || desc.toLowerCase() == 'item';
          final title = (isGeneric ? tileTitle : desc).trim();

          final subtitle = (tileDesc.isEmpty || tileDesc == title)
              ? null
              : tileDesc;

          return SalesDocLineVm(
            title: title.isEmpty ? 'Item' : title,
            subtitle: subtitle,
            qty: line.quantity,
            rate: widget.requirePrices ? line.rate : 0,
          );
        })
        .toList(growable: false);
  }

  Widget _buildBody(BuildContext context, QuoteState s, QuoteController ctl) {
    final meta = _metaVm(s);
    final vmLines = _lineVms(s);
    final busy = s.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),

        ErrorBanner(s.error),

        SalesDocHeader(
          title: 'Quote',
          meta: meta,
          compact: true,
          showStatus: false,
          trailing: _buildHeaderTrailing(context, s, ctl, meta),
        ),

        _buildMetaFields(s, ctl),

        const Divider(height: 1),

        Expanded(
          child: s.draft.lines.isEmpty
              ? const Center(child: Text('No items. Tap + to add.'))
              : SalesDocLinesList(
                  currencyCode: meta.currencyCode,
                  lines: vmLines,
                  mode: SalesDocMode.edit,

                  // ✅ unified edit (item + qty + rate)
                  onEditLine: busy
                      ? null
                      : (index) async {
                          final draftLine = s.draft.lines[index];
                          final tile = draftLine.tile;

                          final res = await SalesDocDialogs.editLine(
                            context,
                            initialName: vmLines[index].title.trim(),
                            initialQty: draftLine.quantity,
                            initialRate: draftLine.rate,
                            enableRate: widget.requirePrices,
                          );
                          if (res == null) return;

                          final name = res.name.trim();
                          if (name.isNotEmpty) ctl.updateDraftName(tile, name);

                          ctl.updateDraftQty(tile, res.qty);

                          if (widget.requirePrices) {
                            ctl.updateDraftRate(tile, res.rate);
                          }
                        },

                  onEditName: null,
                  onEditQtyRate: null,

                  // ✅ delete line confirm
                  onRemoveLine: busy
                      ? null
                      : (index) async {
                          final ok = await SalesDocDialogs.confirmDelete(
                            context,
                            thing: 'line item',
                            message: 'Remove this item from the quote?',
                          );
                          if (!ok) return;

                          final tile = s.draft.lines[index].tile;
                          ctl.updateDraftQty(tile, 0);

                          if (s.draft.lines.length == 1) _clearCatalogCart();
                        },
                ),
        ),

        if (widget.requirePrices)
          SalesDocTotalBar(
            label: _isEdit ? 'Total' : 'Estimated total',
            total: s.total,
            currencyCode: meta.currencyCode,
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Estimated total: — (prices not required)',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),

        _buildSubmitButton(context, s, ctl),
      ],
    );
  }

  Widget _buildHeaderTrailing(
    BuildContext context,
    QuoteState s,
    QuoteController ctl,
    SalesDocMetaVm meta,
  ) {
    final cs = Theme.of(context).colorScheme;
    final busy = s.busy;

    final pickStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, _kTrailH),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final iconStyle = IconButton.styleFrom(
      minimumSize: const Size(_kTrailH, _kTrailH),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return SizedBox(
      height: _kTrailH,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SalesDocStatusChip(
            status: meta.status,
            visualDensity: VisualDensity.compact,
            forceLabel: _isEdit ? 'editing' : 'draft',
          ),
          const SizedBox(width: 8),

          OutlinedButton.icon(
            style: pickStyle,
            icon: const Icon(Icons.person_outline, size: 18),
            label: Text(s.draft.contact == null ? 'Pick' : 'Change'),
            onPressed: busy
                ? null
                : () async {
                    final ok = await _ensureAuthed(context);
                    if (!ok) return;

                    final ZohoContact? picked = await showDialog<ZohoContact>(
                      context: context,
                      builder: (_) => const ContactPickerDialog(),
                    );
                    if (picked == null) return;

                    ctl.patchDraft(contact: picked);
                  },
          ),

          if (_isEdit) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Delete quote',
              style: iconStyle,
              icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
              onPressed: busy
                  ? null
                  : () async {
                      final ok = await SalesDocDialogs.confirmDelete(
                        context,
                        thing: 'quote',
                        message: 'This will delete the quote in Zoho Books.',
                      );
                      if (!ok) return;

                      final id = (s.editingQuoteId ?? '').trim();
                      if (id.isEmpty) return;

                      final done = await ctl.deleteQuote(id);
                      if (!done) return;
                      if (!context.mounted) return;

                      _clearCatalogCart();
                      Navigator.of(context).pop(true);
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaFields(QuoteState s, QuoteController ctl) {
    final busy = s.busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          TextField(
            controller: _refCtl,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Reference',
              hintText: 'e.g. PO number, request reference…',
            ),
            onChanged: (v) => ctl.patchDraft(reference: v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtl,
            enabled: !busy,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Customer notes',
              hintText: 'Notes to appear on the quote…',
            ),
            onChanged: (v) => ctl.patchDraft(customerNotes: v),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(
    BuildContext context,
    QuoteState s,
    QuoteController ctl,
  ) {
    final busy = s.busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: FilledButton.icon(
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(_isEdit ? Icons.save : Icons.send),
        label: Text(
          busy ? 'Submitting…' : (_isEdit ? 'Save changes' : 'Request a quote'),
        ),
        onPressed: busy
            ? null
            : () async {
                final ok = await _ensureAuthed(context);
                if (!ok) return;

                final id = await ctl.submit(
                  requirePrices: widget.requirePrices,
                );
                if (id == null || id.trim().isEmpty) return;
                if (!context.mounted) return;

                _clearCatalogCart();
                Navigator.of(context).pop(true);
              },
      ),
    );
  }
}

enum _AddAction { addCustomLine, goToCatalog }
