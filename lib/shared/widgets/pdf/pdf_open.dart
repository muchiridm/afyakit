// lib/shared/widgets/pdf/pdf_open.dart

import 'dart:typed_data';

import 'pdf_open_stub.dart' if (dart.library.html) 'pdf_open_web.dart';

void openPdfBytes(Uint8List bytes, {String fileName = 'document.pdf'}) {
  openPdfBytesImpl(bytes, fileName: fileName);
}
