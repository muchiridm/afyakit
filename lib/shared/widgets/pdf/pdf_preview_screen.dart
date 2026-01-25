// lib/shared/widgets/pdf/pdf_preview_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'pdf_saver.dart';
import 'pdf_viewer.dart';

class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({
    super.key,
    required this.bytes,
    this.title = 'PDF Preview',
    this.fileName = 'document.pdf',
  });

  final Uint8List bytes;
  final String title;
  final String fileName;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  String? _saveResult;
  bool _saving = false;

  Future<void> _saveCopy() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final result = await savePdfBytes(
        bytes: widget.bytes,
        fileName: widget.fileName,
      );

      if (!mounted) return;
      setState(() => _saveResult = result);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved: $result')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canShowSaved = (_saveResult ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: _saving ? 'Saving…' : 'Save copy',
            onPressed: _saving ? null : _saveCopy,
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (canShowSaved)
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saved: $_saveResult',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: PdfViewer(bytes: widget.bytes)),
        ],
      ),
    );
  }
}
