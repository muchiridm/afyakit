// lib/features/retail/sales/quotes/widgets/quote_editor_screen.dart

import 'package:afyakit/core/auth/auth_user/guards/require_auth.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_state.dart';
import 'package:afyakit/features/retail/shared/models/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/widgets/contact_picker_dialog.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_controller.dart';

import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';

import 'package:afyakit/features/retail/shared/sales_doc/dialogs.dart';
import 'package:afyakit/features/retail/shared/sales_doc/feedback.dart';
import 'package:afyakit/features/retail/shared/sales_doc/header.dart';
import 'package:afyakit/features/retail/shared/sales_doc/lines.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:afyakit/features/retail/shared/sales_doc/status.dart';
import 'package:afyakit/features/retail/shared/sales_doc/totals.dart';
import 'package:afyakit/features/retail/shared/sales_doc/date_pill.dart';

import 'package:afyakit/shared/layout/app_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Editor result used by parent screens (detail/list) to decide navigation.
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
  static const double _contentMaxW = 720;
  static const double _kTrailH = 36;

  final _refCtl = TextEditingController();
  final _notesCtl = TextEditingController();

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

    final oldId = (oldWidget.editingQuoteId ?? '').trim();
    final newId = (widget.editingQuoteId ?? '').trim();
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
      prev,
      next,
    ) {
      final didRefChange = prev?.reference != next.reference;
      final didNotesChange = prev?.customerNotes != next.customerNotes;
      if (!didRefChange && !didNotesChange) return;

      final nextRef = next.reference ?? '';
      final nextNotes = next.customerNotes ?? '';

      if (_refCtl.text != nextRef) _refCtl.text = nextRef;
      if (_notesCtl.text != nextNotes) _notesCtl.text = nextNotes;
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;

    final metaCtl = ref.read(quoteMetaControllerProvider.notifier);
    final id = (widget.editingQuoteId ?? '').trim();
    if (id.isNotEmpty) {
      metaCtl.beginEdit(id);
    }

    final ctl = ref.read(quoteControllerProvider.notifier);
    await ctl.ensureReady(
      editingQuoteId: widget.editingQuoteId,
      requirePrices: widget.requirePrices,
    );
  }

  void _clearQuoteLines() =>
      ref.read(quoteLinesControllerProvider.notifier).clear();

  Future<void> _clearAll() async {
    _clearQuoteLines();
    ref.read(quoteMetaControllerProvider.notifier).clearAll();
    ref.read(quoteControllerProvider.notifier).reset();
  }

  Future<bool> _ensureAuthed(BuildContext context) => requireAuth(context, ref);

  String _currencyCode() => 'KES';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<DateTime?> _pickDate(
    BuildContext context, {
    required DateTime initial,
    DateTime? firstDate,
    DateTime? lastDate,
    required String helpText,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(now.year - 5, 1, 1),
      lastDate: lastDate ?? DateTime(now.year + 10, 12, 31),
      helpText: helpText,
    );
    return picked == null ? null : _dateOnly(picked);
  }

  Future<bool> _handleBack(BuildContext context, QuoteState s) async {
    if (s.busy) return false;

    final hasLines = ref.read(quoteLinesControllerProvider).lines.isNotEmpty;

    final meta = ref.read(quoteMetaControllerProvider);
    final hasMetaEdits =
        (meta.reference ?? '').trim().isNotEmpty ||
        (meta.customerNotes ?? '').trim().isNotEmpty ||
        (meta.contact != null) ||
        (meta.quoteDate != null) ||
        (meta.expiryDate != null);

    if (!hasLines && !hasMetaEdits) return true;

    final ok = _isEdit
        ? await SalesDocDialogs.confirmDiscardChanges(context)
        : await SalesDocDialogs.confirmDiscardCheckout(context);
    if (!ok) return false;

    await _clearAll();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(quoteControllerProvider);
    final ctl = ref.read(quoteControllerProvider.notifier);

    final meta = ref.watch(quoteMetaControllerProvider);
    final metaCtl = ref.read(quoteMetaControllerProvider.notifier);

    final linesState = ref.watch(quoteLinesControllerProvider);

    final policy = ref.watch(quoteContactPolicyProvider);
    final isMemberScoped = policy == QuoteContactPolicy.memberScoped;

    return WillPopScope(
      onWillPop: () => _handleBack(context, s),
      child: AppPage(
        title: _isEdit ? 'Edit quote' : 'Request a quote',
        showBack: true,
        maxWidth: _contentMaxW,
        scrollable: false,
        actions: const <Widget>[],
        body: _buildBody(
          context,
          s,
          ctl,
          meta,
          metaCtl,
          linesState,
          isMemberScoped: isMemberScoped,
        ),
      ),
    );
  }

  SalesDocMetaVm _metaVm(
    QuoteMetaState meta,
    QuoteLinesState linesState, {
    required String fallbackPartyName,
  }) {
    final contactTitle = (meta.contact?.title ?? '').trim();

    final fb = fallbackPartyName.trim();
    final partyName = contactTitle.isNotEmpty
        ? contactTitle
        : (fb.isNotEmpty ? fb : 'Customer');

    final docNo = _isEdit
        ? ((meta.editingQuoteId ?? '').trim().isEmpty
              ? '-'
              : (meta.editingQuoteId ?? '').trim())
        : 'Draft';

    return SalesDocMetaVm(
      partyName: partyName,
      docNumberOrId: docNo,
      status: _isEdit ? 'editing' : 'draft',
      currencyCode: _currencyCode(),
      total: widget.requirePrices ? linesState.estimatedTotal : 0,
      date: meta.quoteDate,
      expiryDate: meta.expiryDate,
    );
  }

  List<_LineBinding> _lineBindings(QuoteLinesState linesState) {
    return linesState.lines
        .map((l) {
          if (l is CatalogQuoteLine) {
            return _LineBinding.catalog(tileId: l.tile.id, key: l.key);
          }
          if (l is ManualQuoteLine) {
            return _LineBinding.manual(manualId: l.manualId, key: l.key);
          }
          return _LineBinding.unknown(key: l.key);
        })
        .toList(growable: false);
  }

  List<SalesDocLineVm> _lineVmsFromLines(QuoteLinesState linesState) {
    return linesState.lines
        .map((line) {
          if (line is CatalogQuoteLine) {
            final title = line.effectiveName.trim().isEmpty
                ? 'Item'
                : line.effectiveName.trim();
            final subtitle = (line.effectiveDescription ?? '').trim().isEmpty
                ? null
                : line.effectiveDescription;

            return SalesDocLineVm(
              title: title,
              subtitle: subtitle,
              qty: line.qty,
              rate: widget.requirePrices ? line.effectiveRate : 0,
            );
          }

          if (line is ManualQuoteLine) {
            final title = line.name.trim().isEmpty ? 'Item' : line.name.trim();
            final subtitle = (line.description ?? '').trim().isEmpty
                ? null
                : line.description;

            return SalesDocLineVm(
              title: title,
              subtitle: subtitle,
              qty: line.qty,
              rate: widget.requirePrices ? line.rate : 0,
            );
          }

          return const SalesDocLineVm(
            title: 'Item',
            subtitle: null,
            qty: 1,
            rate: 0,
          );
        })
        .toList(growable: false);
  }

  Widget _buildBody(
    BuildContext context,
    QuoteState s,
    QuoteController ctl,
    QuoteMetaState meta,
    QuoteMetaController metaCtl,
    QuoteLinesState linesState, {
    required bool isMemberScoped,
  }) {
    final fallbackPartyName = isMemberScoped
        ? ((meta.contact?.title ?? '').trim().isNotEmpty
              ? meta.contact!.title
              : 'Loading customer…')
        : 'Customer';

    final vmMeta = _metaVm(
      meta,
      linesState,
      fallbackPartyName: fallbackPartyName,
    );

    final vmLines = _lineVmsFromLines(linesState);
    final bindings = _lineBindings(linesState);
    final busy = s.busy;

    // 🔒 Member-scoped rule: qty-only.
    final canEditLineDetails = !isMemberScoped; // name/desc only
    final canEditLineRate =
        !isMemberScoped && widget.requirePrices; // staff only

    QuoteLinesController linesCtl() =>
        ref.read(quoteLinesControllerProvider.notifier);

    bool isManualAt(int index) {
      final b = bindings[index];
      final line = linesState.lines[index];
      return b.kind == _LineKind.manual && line is ManualQuoteLine;
    }

    bool isCatalogAt(int index) {
      final b = bindings[index];
      final line = linesState.lines[index];
      return b.kind == _LineKind.catalog && line is CatalogQuoteLine;
    }

    num safeRate(num v) => (v.isNaN || v.isInfinite || v < 0) ? 0 : v;

    String safeName(String s) {
      final t = s.trim();
      return t.isEmpty ? 'Item' : t;
    }

    Future<void> editLineDialog(int index) async {
      final b = bindings[index];
      final line = linesState.lines[index];

      final initialName = vmLines[index].title.trim();
      final initialQty = vmLines[index].qty.toInt();
      final initialDesc = vmLines[index].subtitle ?? '';

      final initialRate = line is CatalogQuoteLine
          ? line.effectiveRate
          : (line is ManualQuoteLine ? line.rate : 0);

      // ✅ Staff: name/desc/qty (+ rate if requirePrices)
      // ✅ Member: qty ONLY (everything else locked)
      final res = await SalesDocDialogs.editLine(
        context,
        initialName: initialName,
        initialDescription: initialDesc,
        initialQty: initialQty,
        initialRate: initialRate,
        enableRate: canEditLineRate,

        // 🔒 Member qty-only; staff full.
        enableName: canEditLineDetails,
        enableDescription: canEditLineDetails,
        enableQty: true,
      );
      if (res == null) return;

      final lc = linesCtl();

      if (b.kind == _LineKind.catalog && line is CatalogQuoteLine) {
        if (isMemberScoped) {
          // ✅ Member: qty only
          lc.updateCatalogLine(
            line.tile,
            lineKey: b.key, // ✅ critical to avoid duplicates
            qty: res.qty,
          );
          return;
        }

        // ✅ Staff: full update
        lc.updateCatalogLine(
          line.tile,
          lineKey: b.key,
          qty: res.qty,
          name: safeName(res.name),
          description: res.description,
          rate: canEditLineRate ? safeRate(res.rate) : line.effectiveRate,
        );
        return;
      }

      if (b.kind == _LineKind.manual && line is ManualQuoteLine) {
        if (isMemberScoped) {
          // Defensive: members shouldn't have manual lines, but keep safe.
          lc.updateManualLine(b.manualId!, qty: res.qty);
          return;
        }

        lc.updateManualLine(
          b.manualId!,
          name: safeName(res.name),
          description: res.description,
          qty: res.qty,
          rate: canEditLineRate ? safeRate(res.rate) : line.rate,
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        ErrorBanner(s.error),

        SalesDocHeader(
          title: 'Quote',
          meta: vmMeta,
          compact: true,
          showStatus: false,
          trailing: _buildHeaderTrailing(
            context,
            s,
            ctl,
            meta,
            metaCtl,
            vmMeta,
            isMemberScoped: isMemberScoped,
          ),
        ),

        _buildMetaFields(context, meta, metaCtl, busy),

        const Divider(height: 1),

        Expanded(
          child: linesState.lines.isEmpty
              ? const Center(
                  child: Text('No items yet. Add from Catalog below.'),
                )
              : SalesDocLinesList(
                  currencyCode: vmMeta.currencyCode,
                  lines: vmLines,
                  mode: SalesDocMode.edit,

                  // 🔒 Member: no name edits
                  onEditName: (!canEditLineDetails || busy)
                      ? null
                      : (int index, String nextName) async {
                          final lc = linesCtl();

                          if (isManualAt(index)) {
                            final b = bindings[index];
                            lc.updateManualLine(
                              b.manualId!,
                              name: safeName(nextName),
                            );
                            return;
                          }

                          if (isCatalogAt(index)) {
                            final b = bindings[index];
                            final line =
                                linesState.lines[index] as CatalogQuoteLine;

                            lc.updateCatalogLine(
                              line.tile,
                              lineKey: b.key,
                              name: safeName(nextName),
                            );
                          }
                        },

                  // ✅ Everyone: qty changes allowed.
                  // 🔒 Member: ignore nextRate completely.
                  onEditQtyRate: busy
                      ? null
                      : (int index, int nextQty, num nextRate) async {
                          final lc = linesCtl();
                          final qty = nextQty;

                          if (isCatalogAt(index)) {
                            final b = bindings[index];
                            final line =
                                linesState.lines[index] as CatalogQuoteLine;

                            if (isMemberScoped) {
                              lc.updateCatalogLine(
                                line.tile,
                                lineKey: b.key,
                                qty: qty,
                              );
                              return;
                            }

                            if (canEditLineRate) {
                              lc.updateCatalogLine(
                                line.tile,
                                lineKey: b.key,
                                qty: qty,
                                rate: safeRate(nextRate),
                              );
                            } else {
                              lc.updateCatalogLine(
                                line.tile,
                                lineKey: b.key,
                                qty: qty,
                              );
                            }
                            return;
                          }

                          if (isManualAt(index)) {
                            final b = bindings[index];
                            final line =
                                linesState.lines[index] as ManualQuoteLine;

                            if (isMemberScoped) {
                              lc.updateManualLine(b.manualId!, qty: qty);
                              return;
                            }

                            if (canEditLineRate) {
                              lc.updateManualLine(
                                b.manualId!,
                                qty: qty,
                                rate: safeRate(nextRate),
                              );
                            } else {
                              lc.updateManualLine(
                                b.manualId!,
                                qty: qty,
                                rate: line.rate,
                              );
                            }
                          }
                        },

                  // ✅ Everyone: edit button opens dialog
                  // - member: qty-only dialog
                  // - staff: full dialog
                  onEditLine: busy
                      ? null
                      : (int index) async => editLineDialog(index),

                  // ✅ Everyone: allow remove line
                  onRemoveLine: busy
                      ? null
                      : (int index) async {
                          final ok = await SalesDocDialogs.confirmDelete(
                            context,
                            thing: 'line item',
                            message: 'Remove this item from the quote?',
                          );
                          if (!ok) return;

                          final key = bindings[index].key;
                          linesCtl().removeByKey(key);
                        },
                ),
        ),

        const Divider(height: 1),

        _buildAddBar(context, s, isMemberScoped: isMemberScoped),

        if (widget.requirePrices)
          SalesDocTotalBar(
            label: _isEdit ? 'Total' : 'Estimated total',
            total: linesState.estimatedTotal,
            currencyCode: vmMeta.currencyCode,
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

        _buildSubmitButton(
          context,
          s,
          ctl,
          meta,
          linesState,
          isMemberScoped: isMemberScoped,
        ),
      ],
    );
  }

  Widget _buildHeaderTrailing(
    BuildContext context,
    QuoteState s,
    QuoteController ctl,
    QuoteMetaState meta,
    QuoteMetaController metaCtl,
    SalesDocMetaVm vmMeta, {
    required bool isMemberScoped,
  }) {
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

    final hasContact = meta.contact != null;

    Future<void> pickContact() async {
      final ok = await _ensureAuthed(context);
      if (!ok) return;

      final ZohoContact? picked = await showDialog<ZohoContact>(
        context: context,
        builder: (_) => const ContactPickerDialog(),
      );
      if (picked == null) return;

      metaCtl.setContact(picked);
    }

    return SizedBox(
      height: _kTrailH,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SalesDocStatusChip(
            status: vmMeta.status,
            visualDensity: VisualDensity.compact,
            forceLabel: _isEdit ? 'editing' : 'draft',
          ),
          if (!isMemberScoped) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: pickStyle,
              icon: const Icon(Icons.person_outline, size: 18),
              label: Text(hasContact ? 'Change' : 'Pick'),
              onPressed: busy ? null : pickContact,
            ),
          ],
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

                      final id = (meta.editingQuoteId ?? '').trim();
                      if (id.isEmpty) return;

                      final done = await ctl.deleteQuote(id);
                      if (!done) return;
                      if (!context.mounted) return;

                      await _clearAll();

                      Navigator.of(context).pop(QuoteEditorResult.deleted);
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaFields(
    BuildContext context,
    QuoteMetaState meta,
    QuoteMetaController metaCtl,
    bool busy,
  ) {
    final qd = meta.quoteDate;
    final ed = meta.expiryDate;

    final now = DateTime.now();
    final initialQuoteDate = qd ?? _dateOnly(now);
    final initialExpiryDate =
        ed ??
        (qd == null
            ? _dateOnly(now.add(const Duration(days: 30)))
            : _dateOnly(qd.add(const Duration(days: 30))));

    Future<void> pickQuoteDate() async {
      final picked = await _pickDate(
        context,
        initial: initialQuoteDate,
        helpText: 'Select quote date',
      );
      if (picked == null) return;

      metaCtl.setQuoteDate(picked);

      final currentExpiry = meta.expiryDate;
      if (currentExpiry == null) {
        metaCtl.setExpiryDate(_dateOnly(picked.add(const Duration(days: 30))));
      }
    }

    Future<void> pickExpiryDate() async {
      final base = meta.quoteDate ?? _dateOnly(DateTime.now());
      final picked = await _pickDate(
        context,
        initial: initialExpiryDate,
        firstDate: base,
        helpText: 'Select expiry date',
      );
      if (picked == null) return;
      metaCtl.setExpiryDate(picked);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SalesDocDatePill(
                  label: 'Date',
                  icon: Icons.event_outlined,
                  date: qd,
                  enabled: !busy,
                  onPick: busy ? null : pickQuoteDate,
                  onClear: busy ? null : () => metaCtl.clearQuoteDate(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SalesDocDatePill(
                  label: 'Expiry',
                  icon: Icons.timelapse_outlined,
                  date: ed,
                  enabled: !busy,
                  onPick: busy ? null : pickExpiryDate,
                  onClear: busy ? null : () => metaCtl.clearExpiryDate(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _refCtl,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Reference',
              hintText: 'e.g. PO number, request reference…',
            ),
            onChanged: metaCtl.setReference,
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
            onChanged: metaCtl.setCustomerNotes,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(
    BuildContext context,
    QuoteState s,
    QuoteController ctl,
    QuoteMetaState meta,
    QuoteLinesState linesState, {
    required bool isMemberScoped,
  }) {
    final busy = s.busy;

    final canSubmit =
        linesState.lines.isNotEmpty &&
        (!widget.requirePrices || linesState.hasAllPrices) &&
        (!isMemberScoped || meta.contact != null);

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
        onPressed: (!canSubmit || busy)
            ? null
            : () async {
                final ok = await _ensureAuthed(context);
                if (!ok) return;

                final id = await ctl.submit(
                  requirePrices: widget.requirePrices,
                );
                if (id == null || id.trim().isEmpty) return;
                if (!context.mounted) return;

                await _clearAll();

                Navigator.of(context).pop(QuoteEditorResult.saved);
              },
      ),
    );
  }

  Widget _buildAddBar(
    BuildContext context,
    QuoteState s, {
    required bool isMemberScoped,
  }) {
    final busy = s.busy;

    if (isMemberScoped) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: FilledButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('Add from Catalog'),
          onPressed: busy
              ? null
              : () async {
                  final ok = await _ensureAuthed(context);
                  if (!ok) return;

                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CatalogScreen(),
                    ),
                  );
                },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Catalog'),
              onPressed: busy
                  ? null
                  : () async {
                      final ok = await _ensureAuthed(context);
                      if (!ok) return;

                      if (!context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CatalogScreen(),
                        ),
                      );
                    },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Custom'),
              onPressed: busy
                  ? null
                  : () async {
                      final ok = await _ensureAuthed(context);
                      if (!ok) return;

                      final res = await SalesDocDialogs.editLine(
                        context,
                        initialName: 'Item',
                        initialDescription: '',
                        initialQty: 1,
                        initialRate: 0,
                        enableRate: widget.requirePrices,
                      );
                      if (res == null) return;

                      ref
                          .read(quoteLinesControllerProvider.notifier)
                          .addManualLine(
                            name: res.name.trim().isEmpty
                                ? 'Item'
                                : res.name.trim(),
                            description: res.description,
                            rate: widget.requirePrices ? res.rate : 0,
                            qty: res.qty,
                          );
                    },
            ),
          ),
        ],
      ),
    );
  }
}

enum _LineKind { catalog, manual, unknown }

@immutable
class _LineBinding {
  const _LineBinding._(
    this.kind, {
    required this.key,
    this.manualId,
    this.tileId,
  });

  final _LineKind kind;
  final String key;
  final String? manualId;
  final String? tileId;

  factory _LineBinding.catalog({required String tileId, required String key}) =>
      _LineBinding._(_LineKind.catalog, tileId: tileId, key: key);

  factory _LineBinding.manual({
    required String manualId,
    required String key,
  }) => _LineBinding._(_LineKind.manual, manualId: manualId, key: key);

  factory _LineBinding.unknown({required String key}) =>
      _LineBinding._(_LineKind.unknown, key: key);
}
