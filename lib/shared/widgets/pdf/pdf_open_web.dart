// lib/shared/widgets/pdf/pdf_open_web.dart

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

void openPdfBytesImpl(Uint8List bytes, {String fileName = 'document.pdf'}) {
  final blob = html.Blob(<Object>[bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..target = '_blank'
    ..rel = 'noopener'
    ..download = fileName;

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  // Do not revoke immediately. Chrome may not have loaded the blob
  // in the new tab yet, especially on Flutter web/debug builds.
  Timer(const Duration(minutes: 2), () {
    html.Url.revokeObjectUrl(url);
  });
}
