import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_labels.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/native_contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Creates/edit profiles and (staff creation only) selects an existing Native Contact.
/// Links and self-identity are always revalidated by the backend.
/// Simple clinical summary first; detailed histories remain optional and preserved.
class ProfileFormDialog extends ConsumerStatefulWidget {
  const ProfileFormDialog({
    super.key,
    this.initial,
    this.initialContact,
    this.initialRelationship,
    this.prefillFromContact = true,
    this.allowExplicitContactLink = false,
  });
  final Profile? initial;
  final NativeContact? initialContact;
  final ProfileContactRelationship? initialRelationship;
  final bool prefillFromContact;
  final bool allowExplicitContactLink;
  @override
  ConsumerState<ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends ConsumerState<ProfileFormDialog> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _dob = TextEditingController(),
      _phone = TextEditingController(),
      _email = TextEditingController(),
      _nationalId = TextEditingController(),
      _notes = TextEditingController();
  final _past = TextEditingController(),
      _surgical = TextEditingController(),
      _family = TextEditingController(),
      _social = TextEditingController(),
      _medicines = TextEditingController();
  ProfileGender _gender = ProfileGender.unknown;
  ProfileContactRelationship _relationship = ProfileContactRelationship.self;
  AllergyStatus _allergyStatus = AllergyStatus.unknown;
  List<ProfileAllergy> _allergies = [];
  List<ProfileCondition> _conditions = [];
  List<ProfileVaccination> _vaccinations = [];
  NativeContact? _contact;
  bool get _staffCreate =>
      widget.initial == null && widget.allowExplicitContactLink;
  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name.text = p?.fullName ?? '';
    _dob.text = p?.dob ?? '';
    _phone.text = p?.phone ?? '';
    _email.text = p?.email ?? '';
    _nationalId.text = p?.nationalId ?? '';
    _notes.text = p?.notes ?? '';
    _past.text = p?.pastMedicalHistory ?? '';
    _surgical.text = p?.surgicalHistory ?? '';
    _family.text = p?.familyHistory ?? '';
    _social.text = p?.socialHistory ?? '';
    _medicines.text = p?.currentMedications ?? '';
    _gender = p?.gender ?? ProfileGender.unknown;
    _allergyStatus = p?.allergyStatus ?? AllergyStatus.unknown;
    _allergies = [...?p?.allergies];
    _conditions = [...?p?.conditions];
    _vaccinations = [...?p?.vaccinations];
    _relationship =
        widget.initialRelationship ??
        (widget.allowExplicitContactLink
            ? ProfileContactRelationship.other
            : ProfileContactRelationship.self);
    _contact = _staffCreate ? widget.initialContact : null;
    if (_contact != null &&
        _relationship == ProfileContactRelationship.self &&
        widget.prefillFromContact) {
      _prefillSelf(_contact!);
    }
  }

  void _prefillSelf(NativeContact c) {
    if (_name.text.trim().isEmpty) _name.text = c.displayName;
    if (_phone.text.trim().isEmpty) {
      _phone.text = c.phone ?? c.mobile ?? c.verifiedPhone ?? '';
    }
    if (_email.text.trim().isEmpty) {
      _email.text = c.email ?? c.verifiedEmail ?? '';
    }
    if (_nationalId.text.trim().isEmpty) _nationalId.text = c.idNumber ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _dob,
      _phone,
      _email,
      _nationalId,
      _notes,
      _past,
      _surgical,
      _family,
      _social,
      _medicines,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    border: const OutlineInputBorder(),
  );
  Widget _field(
    String label,
    TextEditingController c, {
    int lines = 1,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: c,
    maxLines: lines,
    decoration: _dec(label),
    validator: validator,
  );
  String? _date(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return null;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return 'Use YYYY-MM-DD';
    final d = DateTime.tryParse(raw);
    return d == null || d.toIso8601String().substring(0, 10) != raw
        ? 'Invalid date'
        : null;
  }

  Future<void> _chooseContact() async {
    final chosen = await showDialog<NativeContact>(
      context: context,
      builder: (_) => const _ContactSearchDialog(),
    );
    if (!mounted || chosen == null) return;
    setState(() {
      _contact = chosen;
      if (_relationship == ProfileContactRelationship.self) {
        // New self profile is identified from the canonical Contact.
        _name.text = chosen.displayName;
        _phone.text =
            chosen.phone ?? chosen.mobile ?? chosen.verifiedPhone ?? '';
        _email.text = chosen.email ?? chosen.verifiedEmail ?? '';
        _nationalId.text = chosen.idNumber ?? '';
      }
    });
  }

  Future<void> _addAllergy() async {
    final result = await _textRecordDialog('Add allergy', [
      'Substance',
      'Reaction (optional)',
      'Notes (optional)',
    ]);
    if (!mounted || result == null) return;
    setState(() {
      _allergyStatus = AllergyStatus.known;
      _allergies.add(
        ProfileAllergy(
          category: AllergyCategory.drug,
          substance: result[0],
          reaction: result[1],
          notes: result[2],
        ),
      );
    });
  }

  Future<void> _addCondition() async {
    final result = await _textRecordDialog('Add illness / condition', [
      'Condition name',
      'Diagnosis date (YYYY-MM-DD, optional)',
      'Notes (optional)',
    ]);
    if (!mounted || result == null) return;
    if (result[1].isNotEmpty && _date(result[1]) != null) return;
    setState(
      () => _conditions.add(
        ProfileCondition(
          name: result[0],
          diagnosedOn: result[1],
          notes: result[2],
        ),
      ),
    );
  }

  Future<void> _addVaccination() async {
    final result = await _textRecordDialog('Add vaccination', [
      'Vaccine',
      'Administration date (YYYY-MM-DD, optional)',
      'Notes (optional)',
    ]);
    if (!mounted || result == null) return;
    if (result[1].isNotEmpty && _date(result[1]) != null) return;
    setState(
      () => _vaccinations.add(
        ProfileVaccination(
          vaccineName: result[0],
          status: VaccinationStatus.historical,
          administeredOn: result[1],
          notes: result[2],
        ),
      ),
    );
  }

  Future<List<String>?> _textRecordDialog(String title, List<String> labels) =>
      showDialog<List<String>>(
        context: context,
        builder: (_) => _ClinicalEntryDialog(title: title, labels: labels),
      );

  Widget _clinicalList<T>({
    required String title,
    required List<T> values,
    required String Function(T) label,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
      for (var i = 0; i < values.length; i++)
        ListTile(
          dense: true,
          title: Text(label(values[i])),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
            onPressed: () => onRemove(i),
          ),
        ),
    ],
  );

  void _submit() {
    if (!(_key.currentState?.validate() ?? false)) return;
    if (_staffCreate &&
        _relationship == ProfileContactRelationship.self &&
        _contact == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the Native Contact for Self.')),
      );
      return;
    }
    if (_staffCreate &&
        _contact?.entityType == 'organization' &&
        !{
          ProfileContactRelationship.insurance,
          ProfileContactRelationship.other,
        }.contains(_relationship)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Organisation relationships must be Insurance or Other.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      ProfileUpsertInput(
        fullName: _name.text.trim(),
        dob: _dob.text.trim(),
        gender: _gender,
        accountNumber: _staffCreate ? _contact?.accountNumber : null,
        relationship: _relationship,
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        nationalId: _nationalId.text.trim(),
        notes: _notes.text.trim(),
        pastMedicalHistory: _past.text.trim(),
        surgicalHistory: _surgical.text.trim(),
        familyHistory: _family.text.trim(),
        socialHistory: _social.text.trim(),
        currentMedications: _medicines.text.trim(),
        allergyStatus: _allergyStatus,
        allergies: _allergies,
        vaccinations: _vaccinations,
        conditions: _conditions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_editing ? 'Edit health profile' : 'Create health profile'),
    content: SizedBox(
      width: 720,
      height: MediaQuery.sizeOf(context).height * .75,
      child: Form(
        key: _key,
        child: ListView(
          children: [
            const Text(
              'Start with the essentials. Medical history is optional and can be updated later.',
            ),
            const SizedBox(height: 16),
            if (_staffCreate) ...[
              OutlinedButton.icon(
                onPressed: _chooseContact,
                icon: const Icon(Icons.person_search),
                label: Text(
                  _contact == null
                      ? 'Search and link existing Native Contact'
                      : '${_contact!.displayName} (${_contact!.accountNumber})',
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!_editing)
              DropdownButtonFormField<ProfileContactRelationship>(
                key: ValueKey(_relationship),
                initialValue: _relationship,
                decoration: _dec('Patient is Contact’s…'),
                items:
                    (widget.allowExplicitContactLink
                            ? ProfilesLabels.staffLinkRelationships
                            : const [
                                ProfileContactRelationship.self,
                                ProfileContactRelationship.child,
                                ProfileContactRelationship.parent,
                                ProfileContactRelationship.guardian,
                              ])
                        .map(
                          (x) => DropdownMenuItem(
                            value: x,
                            child: Text(ProfilesLabels.relationship(x)),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _relationship = v;
                      if (v == ProfileContactRelationship.self &&
                          _contact != null) {
                        _prefillSelf(_contact!);
                      }
                    });
                  }
                },
              ),
            const SizedBox(height: 12),
            _field(
              'Full name',
              _name,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Full name required' : null,
            ),
            const SizedBox(height: 12),
            _field('Date of birth (YYYY-MM-DD)', _dob, validator: _date),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProfileGender>(
              initialValue: _gender,
              decoration: _dec('Gender'),
              items: ProfileGender.values
                  .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _gender = v);
              },
            ),
            const SizedBox(height: 12),
            _field('Phone', _phone),
            const SizedBox(height: 12),
            _field('Email', _email),
            const SizedBox(height: 12),
            _field('National ID', _nationalId),
            const Divider(height: 32),
            DropdownButtonFormField<AllergyStatus>(
              key: ValueKey(_allergyStatus),
              initialValue: _allergyStatus,
              decoration: _dec('Known allergies'),
              items: AllergyStatus.values
                  .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _allergyStatus = v;
                    if (v != AllergyStatus.known) _allergies.clear();
                  });
                }
              },
            ),
            _clinicalList(
              title: 'Allergy details',
              values: _allergies,
              label: (a) => a.substance,
              onAdd: _addAllergy,
              onRemove: (i) => setState(() {
                _allergies.removeAt(i);
                if (_allergies.isEmpty) _allergyStatus = AllergyStatus.unknown;
              }),
            ),
            const Divider(),
            _clinicalList(
              title: 'Existing medical conditions',
              values: _conditions,
              label: (c) => c.name,
              onAdd: _addCondition,
              onRemove: (i) => setState(() => _conditions.removeAt(i)),
            ),
            const SizedBox(height: 12),
            _field('Current medications (optional)', _medicines, lines: 2),
            const SizedBox(height: 12),
            _field(
              'Other relevant medical history (optional)',
              _past,
              lines: 3,
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Additional clinical details'),
              subtitle: const Text(
                'Optional — surgery, family/social history and vaccinations',
              ),
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              children: [
                _field('Surgical history', _surgical, lines: 2),
                const SizedBox(height: 12),
                _field('Family history', _family, lines: 2),
                const SizedBox(height: 12),
                _field('Social history', _social, lines: 2),
                const SizedBox(height: 12),
                _clinicalList(
                  title: 'Vaccinations',
                  values: _vaccinations,
                  label: (v) => v.vaccineName,
                  onAdd: _addVaccination,
                  onRemove: (i) => setState(() => _vaccinations.removeAt(i)),
                ),
                const SizedBox(height: 12),
                _field('Other notes', _notes, lines: 2),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(_editing ? 'Save changes' : 'Create'),
      ),
    ],
  );
}

/// Owns field controllers for the full dialog route lifecycle, including exit
/// animations. Never dispose controllers in a showDialog() caller's finally.
class _ClinicalEntryDialog extends StatefulWidget {
  const _ClinicalEntryDialog({required this.title, required this.labels});

  final String title;
  final List<String> labels;

  @override
  State<_ClinicalEntryDialog> createState() => _ClinicalEntryDialogState();
}

class _ClinicalEntryDialogState extends State<_ClinicalEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.labels.length,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _add() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final values = _controllers.map((c) => c.text.trim()).toList();
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _controllers[i],
                    decoration: InputDecoration(
                      labelText: widget.labels[i],
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    validator: i == 0
                        ? (value) =>
                              (value ?? '').trim().isEmpty ? 'Required' : null
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _add, child: const Text('Add')),
    ],
  );
}

class _ContactSearchDialog extends ConsumerStatefulWidget {
  const _ContactSearchDialog();
  @override
  ConsumerState<_ContactSearchDialog> createState() =>
      _ContactSearchDialogState();
}

class _ContactSearchDialogState extends ConsumerState<_ContactSearchDialog> {
  final _query = TextEditingController();
  List<NativeContact> _results = [];
  bool _loading = false;
  String? _error;
  int _request = 0;
  @override
  void dispose() {
    _request++;
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _error = 'Enter at least 2 characters';
      });
      return;
    }
    final id = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = await ref.read(nativeContactsServiceProvider.future);
      final matches = await svc.search(q);
      if (!mounted || id != _request) return;
      setState(() {
        _results = matches.where((c) => c.isActive).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted && id == _request) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Find Native Contact'),
    content: SizedBox(
      width: 560,
      height: 400,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: 'Name, account, email or phone',
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          Expanded(
            child: ListView(
              children: [
                for (final c in _results)
                  ListTile(
                    title: Text(c.displayName),
                    subtitle: Text(
                      '${c.accountNumber} · ${c.phone ?? c.mobile ?? c.email ?? ''}',
                    ),
                    onTap: () => Navigator.pop(context, c),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
