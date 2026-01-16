import 'dart:typed_data';
import 'dart:html' as html;

import 'package:flutter/material.dart';

class PdfViewer extends StatelessWidget {
  const PdfViewer({super.key, required this.bytes});

  final Uint8List bytes;

  void _openInNewTab() {
    final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // open a new tab
    html.window.open(url, '_blank');

    // revoke later (give the browser a moment to load it)
    Future<void>.delayed(const Duration(seconds: 2), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: _openInNewTab,
        icon: const Icon(Icons.open_in_new),
        label: const Text('Open PDF'),
      ),
    );
  }
}
