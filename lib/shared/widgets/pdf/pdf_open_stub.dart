// lib/shared/widgets/pdf/pdf_open_stub.dart

import 'dart:typed_data';

void openPdfBytesImpl(Uint8List bytes, {String fileName = 'document.pdf'}) {
  // Non-web: no-op.
  // Native/mobile/desktop should use PdfPreviewScreen instead.
}
