import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/features/reports/controllers/stock_report_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReactiveCellField extends ConsumerStatefulWidget {
  final String keyId;
  final String itemId;
  final ItemType itemType;
  final String field;
  final String initialValue;
  final bool enabled;
  final TextInputType keyboardType;
  final TextAlign textAlign;

  const ReactiveCellField({
    super.key,
    required this.keyId,
    required this.itemId,
    required this.itemType,
    required this.field,
    required this.initialValue,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.textAlign = TextAlign.left,
  });

  @override
  ConsumerState<ReactiveCellField> createState() => _ReactiveCellFieldState();
}

class _ReactiveCellFieldState extends ConsumerState<ReactiveCellField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _handleSubmit(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit(String newValue) {
    ref
        .read(stockReportControllerProvider)
        .handleCellSubmit(
          context: context,
          key: widget.keyId,
          itemId: widget.itemId,
          itemType: widget.itemType,
          field: widget.field,
          newValue: newValue,
        );
  }

  @override
  Widget build(BuildContext context) {
    return _buildEditableContainer(child: _buildTextField());
  }

  Widget _buildEditableContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.teal.shade100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: child,
    );
  }

  Widget _buildTextField() {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      textAlign: widget.textAlign,
      onFieldSubmitted: _handleSubmit,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
}
