// lib/features/retail/quotes/extensions/quote_editor_mode_x.dart

enum QuoteEditorMode { create, edit, preview }

extension QuoteEditorModeX on QuoteEditorMode {
  bool get canEditHeader =>
      this == QuoteEditorMode.create || this == QuoteEditorMode.edit;
  bool get canEditLines =>
      this == QuoteEditorMode.create || this == QuoteEditorMode.edit;
  bool get canPickContact =>
      this == QuoteEditorMode.create; // lock in edit & preview
  bool get showCatalog =>
      this != QuoteEditorMode.preview; // preview stays clean
  bool get canSubmit =>
      this == QuoteEditorMode.create || this == QuoteEditorMode.edit;

  String title({required int lineCount}) {
    switch (this) {
      case QuoteEditorMode.create:
        return 'New Quote';
      case QuoteEditorMode.edit:
        return 'Edit Quote';
      case QuoteEditorMode.preview:
        return 'Quote Preview';
    }
  }

  String submitLabel({required int lineCount}) {
    switch (this) {
      case QuoteEditorMode.create:
        return 'Create quote ($lineCount items)';
      case QuoteEditorMode.edit:
        return 'Update quote ($lineCount items)';
      case QuoteEditorMode.preview:
        return 'Edit quote'; // if you ever show a button in preview
    }
  }
}
