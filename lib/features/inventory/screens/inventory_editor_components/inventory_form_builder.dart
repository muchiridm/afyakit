import 'package:flutter/material.dart';

class InventoryFormBuilder extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final VoidCallback onSubmit;
  final String buttonLabel;

  const InventoryFormBuilder({
    super.key,
    required this.formKey,
    required this.fields,
    required this.onSubmit,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...fields,
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onSubmit, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
