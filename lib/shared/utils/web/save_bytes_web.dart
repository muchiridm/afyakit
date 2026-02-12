// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void saveBytesAsFileWeb({
  required Uint8List bytes,
  required String filename,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final a = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';

  html.document.body?.children.add(a);
  a.click();
  a.remove();

  html.Url.revokeObjectUrl(url);
}
