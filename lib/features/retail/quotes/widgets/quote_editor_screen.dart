// lib/features/retail/quotes/widgets/quote_editor_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/quote_editor_controller.dart';
import '../controllers/quote_editor_state.dart';
import '../extensions/quote_editor_mode_x.dart';

import 'catalog_sliver.dart';
import 'quote_header_card.dart';
import 'quote_lines_sliver.dart';

class QuoteEditorScreen extends ConsumerStatefulWidget {
  const QuoteEditorScreen({
    super.key,
    this.quoteId,
    this.mode = QuoteEditorMode.create,
  });

  final String? quoteId;
  final QuoteEditorMode mode;

  @override
  ConsumerState<QuoteEditorScreen> createState() => _QuoteEditorScreenState();
}

class _QuoteEditorScreenState extends ConsumerState<QuoteEditorScreen> {
  bool _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;

    Future.microtask(() async {
      final ctl = ref.read(quoteEditorControllerProvider.notifier);
      await ctl.init(
        mode: widget.mode,
        quoteId: widget.quoteId,
        loadCatalog: widget.mode.showCatalog,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quoteEditorControllerProvider);
    final ctl = ref.read(quoteEditorControllerProvider.notifier);

    return Scaffold(
      appBar: _buildAppBar(state, ctl),
      body: _buildBody(state, ctl),
    );
  }

  PreferredSizeWidget _buildAppBar(
    QuoteEditorState state,
    QuoteEditorController ctl,
  ) {
    final busy = state.loadingCatalog || state.loadingQuote;

    return AppBar(
      title: Text(state.mode.title(lineCount: state.draft.lines.length)),
      actions: [
        if (state.mode == QuoteEditorMode.preview)
          TextButton.icon(
            onPressed: busy ? null : () => _goToEdit(state),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        if (state.mode.showCatalog)
          IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : () => ctl.search(reset: true),
            icon: const Icon(Icons.refresh),
          ),
      ],
    );
  }

  void _goToEdit(QuoteEditorState state) {
    final id = (state.quoteId ?? '').trim();
    if (id.isEmpty) return;

    // This is navigation; context-based is fine (UI owns navigation).
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            QuoteEditorScreen(quoteId: id, mode: QuoteEditorMode.edit),
      ),
    );
  }

  Widget _buildBody(QuoteEditorState state, QuoteEditorController ctl) {
    final mode = state.mode;
    final busy = state.loadingCatalog || state.loadingQuote;

    final submitLabel = mode.submitLabel(lineCount: state.draft.lines.length);
    final canPickContact = mode.canPickContact && !state.loadingQuote;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: QuoteHeaderCard(
                state: state,
                onPickContact: canPickContact ? ctl.openContactPicker : null,
                onClearContact: canPickContact ? ctl.clearContact : null,
                onReferenceChanged: mode.canEditHeader
                    ? ctl.setReference
                    : null,
                onNotesChanged: mode.canEditHeader ? ctl.setNotes : null,
                onSubmit: mode.canSubmit ? ctl.submit : null,
                submitLabel: submitLabel,
                disableEditing: !mode.canEditHeader,
              ),
            ),

            // ✅ One-page preview: always show lines inline
            QuoteLinesSliver(
              state: state,
              ctl: ctl,
              readOnly: !mode.canEditLines,
            ),

            if (mode.showCatalog)
              SliverToBoxAdapter(child: _buildSearchBar(state, ctl)),

            if (state.error != null)
              SliverToBoxAdapter(
                child: _ErrorBanner(
                  message: state.error!,
                  onRetry: mode.showCatalog
                      ? () => ctl.search(reset: true)
                      : null,
                ),
              ),

            if (mode.showCatalog)
              CatalogSliver(
                state: state,
                enabled: mode.canEditLines,
                onAdd: ctl.addTileToDraft,
                onLoadMore: () => ctl.search(reset: false),
                onClearSearch: () => ctl.setQuery(''),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),

        if (busy) const LinearProgressIndicator(minHeight: 2),

        if (state.savingQuote)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
      ],
    );
  }

  Widget _buildSearchBar(QuoteEditorState state, QuoteEditorController ctl) {
    final loading = state.loadingCatalog;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search DawaIndex sales…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: state.q.trim().isEmpty
              ? (loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null)
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: () => ctl.setQuery(''),
                  icon: const Icon(Icons.clear),
                ),
        ),
        onChanged: ctl.setQuery,
        onSubmitted: (_) => ctl.search(reset: true),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
              if (onRetry != null)
                IconButton(
                  tooltip: 'Retry',
                  onPressed: onRetry,
                  icon: Icon(Icons.refresh, color: scheme.onErrorContainer),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
