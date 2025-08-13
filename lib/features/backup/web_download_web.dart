import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadJsonInWeb(String json, String filename) async {
  final blob = html.Blob([utf8.encode(json)], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();

  html.Url.revokeObjectUrl(url);
}
