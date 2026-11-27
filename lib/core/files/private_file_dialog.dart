import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:afyakit/shared/widgets/pdf/pdf_viewer.dart';
import 'private_file.dart';

Future<void> showPrivateFile(BuildContext context, PrivateFile file) async {
  if (!file.isCurrent()) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _PrivateFileDialog(file),
  );
}

class _PrivateFileDialog extends StatefulWidget {
  const _PrivateFileDialog(this.file);
  final PrivateFile file;
  @override
  State<_PrivateFileDialog> createState() => _PrivateFileDialogState();
}

class _PrivateFileDialogState extends State<_PrivateFileDialog> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && !widget.file.isCurrent()) {
        _timer?.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    if (!file.isCurrent()) return const SizedBox.shrink();
    return AlertDialog(
      title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 720,
        height: 520,
        child: file.contentType == 'application/pdf'
            ? PdfViewer(bytes: file.bytes)
            : InteractiveViewer(
                child: Image.memory(file.bytes, fit: BoxFit.contain),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
