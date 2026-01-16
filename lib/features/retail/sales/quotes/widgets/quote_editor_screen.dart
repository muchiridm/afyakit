// lib/features/retail/quotes/widgets/quote_editor_screen.dart

import 'package:afyakit/core/auth_user/guards/require_auth.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/widgets/contact_picker_dialog.dart';
import 'package:afyakit/features/retail/sales/quotes/controllers/quote_controller.dart';
import 'package:afyakit/features/retail/sales/quotes/controllers/quote_state.dart';
import 'package:afyakit/features/retail/sales/quotes/widgets/quote_flow_widgets.dart';
import 'package:afyakit/features/retail/sales/widgets/sales_doc_body.dart';
import 'package:afyakit/features/retail/sales/widgets/sales_doc_header.dart';
import 'package:afyakit/shared/layout/app_page_scaffold.dart';
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
  final _refCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  ProviderSubscription<QuoteState>? _draftSub;

  bool get _isEdit => (widget.editingQuoteId ?? '').trim().isNotEmpty;

  // ───────────────────────── lifecycle ─────────────────────────

  @override
  void initState() {
    super.initState();
    _bindDraftTextControllers();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _bootstrap();
    });
  }

  @override
  void didUpdateWidget(covariant QuoteEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldId = (oldWidget.editingQuoteId ?? '').trim();
    final newId = (widget.editingQuoteId ?? '').trim();
    if (oldId == newId) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _bootstrap();
    });
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
      final prevId = prev?.loadedEditId;
      final nextId = next.loadedEditId;

      final didLoadChange = prevId != nextId;
      final didDraftChange = prev?.draft != next.draft;
      if (!didLoadChange && !didDraftChange) return;

      final nextRef = (next.draft.reference ?? '');
      final nextNotes = (next.draft.customerNotes ?? '');

      if (_refCtl.text != nextRef) _refCtl.text = nextRef;
      if (_notesCtl.text != nextNotes) _notesCtl.text = nextNotes;
    });
  }

  Future<void> _bootstrap() async {
    final ctl = ref.read(quoteControllerProvider.notifier);
    await ctl.ensureReady(
      editingQuoteId: widget.editingQuoteId,
      requirePrices: widget.requirePrices,
    );
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(quoteControllerProvider);
    final ctl = ref.read(quoteControllerProvider.notifier);

    return WillPopScope(
      onWillPop: () => _handleBack(context, s, ctl),
      child: AppPageScaffold(
        appBar: _buildAppBar(context, s, ctl),
        scrollable: false, // we manage internal layout with Expanded
        body: _buildBody(context, s, ctl),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    QuoteState s,
    QuoteController ctl,
  ) {
    return AppBar(
      title: Text(_isEdit ? 'Edit quote' : 'Request a quote'),
      actions: [
        if (_isEdit)
          TextButton(
            onPressed: s.busy
                ? null
                : () async {
                    final ok = await _confirmDiscard(context);
                    if (!ok) return;
                    ctl.cancelEdit();
                    if (!context.mounted) return;
                    Navigator.of(context).pop(false); // changed=false
                  },
            child: const Text('Cancel'),
          ),
      ],
      bottom: (s.busy)
          ? const PreferredSize(
              preferredSize: Size.fromHeight(2),
              child: LinearProgressIndicator(minHeight: 2),
            )
          : null,
    );
  }

  // ───────────────────────── actions / navigation ─────────────────────────

  Future<bool> _ensureAuthed(BuildContext context) => requireAuth(context, ref);

  Future<bool> _handleBack(
    BuildContext context,
    QuoteState s,
    QuoteController ctl,
  ) async {
    if (!_isEdit) return true; // create-mode: allow back
    if (s.busy) return false; // block while busy

    final ok = await _confirmDiscard(context);
    if (!ok) return false;

    ctl.cancelEdit();
    return true;
  }

  // ───────────────────────── VM adapters ─────────────────────────

  String _currencyCodeFromState(QuoteState s) => 'KES';

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
          final tileTitle = (tile.tileTitle).trim();
          final tileDesc = (tile.tileDesc ?? '').trim();

          final isGeneric = desc.isEmpty || desc.toLowerCase() == 'item';
          final title = (isGeneric ? tileTitle : desc).trim();

          final subtitle = tileDesc.isEmpty || tileDesc == title
              ? null
              : tileDesc;

          return SalesDocLineVm(
            title: title,
            subtitle: subtitle,
            qty: line.quantity,
            rate: widget.requirePrices ? line.rate : 0,
          );
        })
        .toList(growable: false);
  }

  // ───────────────────────── UI builders ─────────────────────────

  Widget _buildBody(BuildContext context, QuoteState s, QuoteController ctl) {
    final lines = s.draft.lines;
    final hasLines = lines.isNotEmpty;

    if (!hasLines) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErrorBanner(s.error),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No items. Add items from the catalog.'),
          ),
        ],
      );
    }

    final meta = _metaVm(s);
    final vmLines = _lineVms(s);
    final busy = s.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ErrorBanner(s.error),

        // Header panel
        SalesDocHeader(
          title: 'Quote',
          meta: meta,
          compact: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPickCustomerButton(context, s, ctl),
              if (_isEdit) ...[
                const SizedBox(width: 8),
                _buildDeleteButton(context, s, ctl),
              ],
            ],
          ),
        ),

        _buildMetaFields(s, ctl),

        const Divider(height: 1),

        // Lines (fills the middle)
        Expanded(
          child: SalesDocLinesList(
            currencyCode: meta.currencyCode,
            lines: vmLines,
            mode: SalesDocMode.edit,

            onEditName: busy
                ? null
                : (index) async {
                    final current = vmLines[index].title.trim();
                    final next = await _editTextDialog(
                      context,
                      title: 'Line name',
                      initial: current,
                    );
                    if (next == null) return;

                    final tile = s.draft.lines[index].tile;
                    ctl.updateDraftName(tile, next);
                  },

            onEditQtyRate: busy
                ? null
                : (index) async {
                    final line = s.draft.lines[index];

                    final res = await _editQtyRateDialog(
                      context,
                      title: 'Edit line',
                      initialQty: line.quantity,
                      initialRate: line.rate,
                      enableRate: widget.requirePrices,
                    );
                    if (res == null) return;

                    final tile = line.tile;

                    if (res.qty <= 0) {
                      ctl.updateDraftQty(tile, 0);
                      return;
                    }

                    ctl.updateDraftQty(tile, res.qty);

                    if (widget.requirePrices) {
                      ctl.updateDraftRate(tile, res.rate);
                    }
                  },

            onRemoveLine: busy
                ? null
                : (index) {
                    final tile = s.draft.lines[index].tile;
                    ctl.updateDraftQty(tile, 0);
                  },
          ),
        ),

        // Bottom bar(s)
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

  Widget _buildPickCustomerButton(
    BuildContext context,
    QuoteState s,
    QuoteController ctl,
  ) {
    final busy = s.busy;
    final contact = s.draft.contact;

    return OutlinedButton.icon(
      icon: const Icon(Icons.person_outline),
      label: Text(contact == null ? 'Pick' : 'Change'),
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
    );
  }

  Widget _buildDeleteButton(
    BuildContext context,
    QuoteState s,
    QuoteController ctl,
  ) {
    final busy = s.busy;

    return IconButton(
      tooltip: 'Delete quote',
      icon: const Icon(Icons.delete_outline),
      onPressed: busy
          ? null
          : () async {
              final ok = await _confirmDelete(context);
              if (!ok) return;

              final id = (s.editingQuoteId ?? '').trim();
              if (id.isEmpty) return;

              final done = await ctl.deleteQuote(id);
              if (!done) return;
              if (!context.mounted) return;

              Navigator.of(context).pop(true); // changed=true
            },
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

                Navigator.of(context).pop(true); // changed=true
              },
      ),
    );
  }

  // ───────────────────────── dialogs ─────────────────────────

  Future<bool> _confirmDelete(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete quote?'),
        content: const Text('This will delete the quote in Zoho Books.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<String?> _editTextDialog(
    BuildContext context, {
    required String title,
    required String initial,
  }) async {
    final ctl = TextEditingController(text: initial);
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final t = (res ?? '').trim();
    return t.isEmpty ? null : t;
  }
}

class _QtyRateResult {
  const _QtyRateResult(this.qty, this.rate);
  final int qty;
  final num rate;
}

Future<_QtyRateResult?> _editQtyRateDialog(
  BuildContext context, {
  required String title,
  required int initialQty,
  required num initialRate,
  required bool enableRate,
}) async {
  final qtyCtl = TextEditingController(text: initialQty.toString());
  final rateCtl = TextEditingController(text: initialRate.toString());

  final res = await showDialog<_QtyRateResult?>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: qtyCtl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: rateCtl,
            enabled: enableRate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Rate',
              border: const OutlineInputBorder(),
              helperText: enableRate ? null : 'Rate editing disabled',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final qty = int.tryParse(qtyCtl.text.trim()) ?? initialQty;

            final num rate;
            if (!enableRate) {
              rate = initialRate;
            } else {
              final parsed = num.tryParse(rateCtl.text.trim());
              rate = (parsed == null || parsed.isNaN || parsed.isInfinite)
                  ? initialRate
                  : parsed;
            }

            Navigator.pop(context, _QtyRateResult(qty, rate));
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  return res;
}
