// lib/features/retail/sales/invoices/extensions/invoice_editor_mode_x.dart

enum InvoiceEditorMode { create, edit, preview }

extension InvoiceEditorModeX on InvoiceEditorMode {
  bool get canEditHeader =>
      this == InvoiceEditorMode.create || this == InvoiceEditorMode.edit;
  bool get canEditLines =>
      this == InvoiceEditorMode.create || this == InvoiceEditorMode.edit;

  // Same logic as quote: lock contact on edit/preview.
  bool get canPickContact => this == InvoiceEditorMode.create;

  bool get showCatalog =>
      this != InvoiceEditorMode.preview; // preview stays clean

  bool get canSubmit =>
      this == InvoiceEditorMode.create || this == InvoiceEditorMode.edit;

  String title({required int lineCount}) {
    switch (this) {
      case InvoiceEditorMode.create:
        return 'New Invoice';
      case InvoiceEditorMode.edit:
        return 'Edit Invoice';
      case InvoiceEditorMode.preview:
        return 'Invoice Preview';
    }
  }

  String submitLabel({required int lineCount}) {
    switch (this) {
      case InvoiceEditorMode.create:
        return 'Create invoice ($lineCount items)';
      case InvoiceEditorMode.edit:
        return 'Update invoice ($lineCount items)';
      case InvoiceEditorMode.preview:
        return 'Edit invoice';
    }
  }
}
