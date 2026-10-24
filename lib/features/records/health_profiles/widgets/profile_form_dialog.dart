import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_labels.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/native_contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Creates/edit profiles and (staff creation only) selects an existing Native Contact.
/// Links and self-identity are always revalidated by the backend.
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
  bool _active = true;
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
    _active = p?.isActive ?? true;
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
    if (_phone.text.trim().isEmpty)
      _phone.text = c.phone ?? c.mobile ?? c.verifiedPhone ?? '';
    if (_email.text.trim().isEmpty)
      _email.text = c.email ?? c.verifiedEmail ?? '';
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
    if (result == null) return;
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
    if (result == null) return;
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
    if (result == null) return;
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

  Future<List<String>?> _textRecordDialog(
    String title,
    List<String> labels,
  ) async {
    final controls = List.generate(
      labels.length,
      (_) => TextEditingController(),
    );
    final formKey = GlobalKey<FormState>();
    try {
      return await showDialog<List<String>>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controls[i],
                        decoration: _dec(labels[i]),
                        validator: i == 0
                            ? (v) =>
                                  (v ?? '').trim().isEmpty ? 'Required' : null
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(
                    ctx,
                    controls.map((c) => c.text.trim()).toList(),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );
    } finally {
      for (final c in controls) {
        c.dispose();
      }
    }
  }

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
        isActive: _active,
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
              decoration: _dec('Allergy status'),
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
              title: 'Allergies',
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
              title: 'Chronic illnesses / conditions',
              values: _conditions,
              label: (c) => c.name,
              onAdd: _addCondition,
              onRemove: (i) => setState(() => _conditions.removeAt(i)),
            ),
            const Divider(),
            _clinicalList(
              title: 'Vaccinations',
              values: _vaccinations,
              label: (v) => v.vaccineName,
              onAdd: _addVaccination,
              onRemove: (i) => setState(() => _vaccinations.removeAt(i)),
            ),
            const Divider(height: 32),
            _field('Past medical history', _past, lines: 3),
            const SizedBox(height: 12),
            _field('Surgical history', _surgical, lines: 2),
            const SizedBox(height: 12),
            _field('Family history', _family, lines: 2),
            const SizedBox(height: 12),
            _field('Social history', _social, lines: 2),
            const SizedBox(height: 12),
            _field('Current medications', _medicines, lines: 2),
            const SizedBox(height: 12),
            _field('Other notes', _notes, lines: 2),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
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
      if (mounted && id == _request)
        setState(() {
          _error = '$e';
          _loading = false;
        });
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
