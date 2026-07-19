// lib/features/health_metrics/widgets/health_metric_entry_dialog.dart

import 'package:flutter/material.dart';

import '../models/health_metric_entry.dart';
import '../models/health_metric_type.dart';

class HealthMetricEntryDialog extends StatefulWidget {
  const HealthMetricEntryDialog({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.type,
  });

  final String patientId;
  final String patientName;
  final HealthMetricType type;

  static Future<HealthMetricCreateInput?> show(
    BuildContext context, {
    required String patientId,
    required String patientName,
    required HealthMetricType type,
  }) {
    return showDialog<HealthMetricCreateInput>(
      context: context,
      builder: (_) => HealthMetricEntryDialog(
        patientId: patientId,
        patientName: patientName,
        type: type,
      ),
    );
  }

  @override
  State<HealthMetricEntryDialog> createState() {
    return _HealthMetricEntryDialogState();
  }
}

class _HealthMetricEntryDialogState extends State<HealthMetricEntryDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _primaryCtl;
  late final TextEditingController _secondaryCtl;
  late final TextEditingController _notesCtl;

  late DateTime _recordedAt;

  String? _context;
  bool _submitting = false;

  HealthMetricType get _type => widget.type;

  @override
  void initState() {
    super.initState();

    _primaryCtl = TextEditingController();
    _secondaryCtl = TextEditingController();
    _notesCtl = TextEditingController();

    _recordedAt = DateTime.now();
    _context = _defaultContext(_type);
  }

  @override
  void dispose() {
    _primaryCtl.dispose();
    _secondaryCtl.dispose();
    _notesCtl.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(_iconFor(_type)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _type.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.patientName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (_type == HealthMetricType.bloodPressure)
                  _BloodPressureFields(
                    systolicController: _primaryCtl,
                    diastolicController: _secondaryCtl,
                  )
                else
                  TextFormField(
                    controller: _primaryCtl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _valueLabel(_type),
                      suffixText: _type.unit,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        _validateValue(value, label: _valueLabel(_type)),
                  ),
                if (_contextOptions(_type).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _context,
                    decoration: const InputDecoration(
                      labelText: 'Context',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final option in _contextOptions(_type))
                        DropdownMenuItem<String>(
                          value: option.value,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) {
                            setState(() {
                              _context = value;
                            });
                          },
                  ),
                ],
                const SizedBox(height: 16),
                _RecordedAtField(
                  value: _recordedAt,
                  onChanged: _submitting
                      ? null
                      : (value) {
                          setState(() {
                            _recordedAt = value;
                          });
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesCtl,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Optional',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final primaryValue = double.tryParse(_primaryCtl.text.trim());

    final secondaryValue = _type == HealthMetricType.bloodPressure
        ? double.tryParse(_secondaryCtl.text.trim())
        : null;

    if (primaryValue == null) return;

    setState(() {
      _submitting = true;
    });

    Navigator.of(context).pop(
      HealthMetricCreateInput(
        patientId: widget.patientId,
        type: _type,
        recordedAt: _recordedAt,
        primaryValue: primaryValue,
        secondaryValue: secondaryValue,
        context: _nullable(_context),
        notes: _nullable(_notesCtl.text),
      ),
    );
  }

  static String? _validateValue(String? value, {required String label}) {
    final raw = value?.trim() ?? '';

    if (raw.isEmpty) {
      return '$label is required';
    }

    final parsed = double.tryParse(raw);

    if (parsed == null) {
      return 'Enter a valid number';
    }

    if (parsed <= 0) {
      return '$label must be greater than zero';
    }

    return null;
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _BloodPressureFields extends StatelessWidget {
  const _BloodPressureFields({
    required this.systolicController,
    required this.diastolicController,
  });

  final TextEditingController systolicController;
  final TextEditingController diastolicController;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: systolicController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Systolic',
              suffixText: 'mmHg',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final raw = value?.trim() ?? '';

              if (raw.isEmpty) {
                return 'Required';
              }

              final parsed = double.tryParse(raw);

              if (parsed == null || parsed <= 0) {
                return 'Invalid';
              }

              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: diastolicController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Diastolic',
              suffixText: 'mmHg',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final raw = value?.trim() ?? '';

              if (raw.isEmpty) {
                return 'Required';
              }

              final parsed = double.tryParse(raw);

              if (parsed == null || parsed <= 0) {
                return 'Invalid';
              }

              return null;
            },
          ),
        ),
      ],
    );
  }
}

class _RecordedAtField extends StatelessWidget {
  const _RecordedAtField({required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime>? onChanged;

  @override
  Widget build(BuildContext context) {
    final date =
        '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';

    final time =
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onChanged == null ? null : () => _pickDateTime(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Recorded at',
          prefixIcon: Icon(Icons.event_outlined),
          border: OutlineInputBorder(),
        ),
        child: Text('$date at $time'),
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (date == null || !context.mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );

    if (time == null) return;

    onChanged?.call(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}

class _ContextOption {
  const _ContextOption(this.value, this.label);

  final String value;
  final String label;
}

List<_ContextOption> _contextOptions(HealthMetricType type) {
  switch (type) {
    case HealthMetricType.bloodPressure:
      return const [
        _ContextOption('seated', 'Seated'),
        _ContextOption('standing', 'Standing'),
        _ContextOption('lying', 'Lying down'),
        _ContextOption('resting', 'Resting'),
        _ContextOption('post_exercise', 'After exercise'),
      ];

    case HealthMetricType.bloodGlucose:
      return const [
        _ContextOption('fasting', 'Fasting'),
        _ContextOption('random', 'Random'),
        _ContextOption('pre_meal', 'Before meal'),
        _ContextOption('post_meal', 'After meal'),
      ];

    case HealthMetricType.pulse:
    case HealthMetricType.respiratoryRate:
    case HealthMetricType.oxygenSaturation:
      return const [
        _ContextOption('resting', 'Resting'),
        _ContextOption('post_exercise', 'After exercise'),
      ];

    case HealthMetricType.temperature:
      return const [
        _ContextOption('oral', 'Oral'),
        _ContextOption('axillary', 'Axillary'),
        _ContextOption('tympanic', 'Ear'),
        _ContextOption('temporal', 'Temporal'),
      ];

    case HealthMetricType.weight:
    case HealthMetricType.height:
    case HealthMetricType.waistCircumference:
      return const [];
  }
}

String? _defaultContext(HealthMetricType type) {
  final options = _contextOptions(type);

  return options.isEmpty ? null : options.first.value;
}

String _valueLabel(HealthMetricType type) {
  switch (type) {
    case HealthMetricType.bloodPressure:
      return 'Blood pressure';

    case HealthMetricType.bloodGlucose:
      return 'Blood glucose';

    case HealthMetricType.weight:
      return 'Weight';

    case HealthMetricType.height:
      return 'Height';

    case HealthMetricType.pulse:
      return 'Pulse';

    case HealthMetricType.respiratoryRate:
      return 'Respiratory rate';

    case HealthMetricType.oxygenSaturation:
      return 'Oxygen saturation';

    case HealthMetricType.temperature:
      return 'Temperature';

    case HealthMetricType.waistCircumference:
      return 'Waist circumference';
  }
}

IconData _iconFor(HealthMetricType type) {
  switch (type) {
    case HealthMetricType.bloodPressure:
      return Icons.bloodtype_outlined;

    case HealthMetricType.bloodGlucose:
      return Icons.water_drop_outlined;

    case HealthMetricType.weight:
      return Icons.monitor_weight_outlined;

    case HealthMetricType.height:
      return Icons.height;

    case HealthMetricType.pulse:
      return Icons.favorite_border;

    case HealthMetricType.respiratoryRate:
      return Icons.air;

    case HealthMetricType.oxygenSaturation:
      return Icons.sensors_outlined;

    case HealthMetricType.temperature:
      return Icons.thermostat_outlined;

    case HealthMetricType.waistCircumference:
      return Icons.straighten;
  }
}
