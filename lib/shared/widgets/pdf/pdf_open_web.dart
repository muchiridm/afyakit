// lib/shared/widgets/pdf/pdf_open_web.dart
import 'dart:typed_data';
import 'dart:html' as html;

void openPdfBytesImpl(Uint8List bytes) {
  final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.window.open(url, '_blank');

  Future<void>.delayed(const Duration(seconds: 2), () {
    html.Url.revokeObjectUrl(url);
  });
}
