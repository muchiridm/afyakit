import 'dart:typed_data';
import 'dart:html' as html;

Future<String> savePdfBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final a = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.children.add(a);
  a.click();
  a.remove();

  html.Url.revokeObjectUrl(url);

  // On web there is no file path. Return a friendly marker.
  return 'downloaded:$fileName';
}
