import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/user_models.dart';
import '../providers/user_home_providers.dart';

/// Edits the Medical ID: blood type, body, allergies, conditions, the
/// emergency contact and insurance.
class MedicalIdFormPage extends ConsumerStatefulWidget {
  const MedicalIdFormPage({super.key, required this.initial});

  final MedicalProfile initial;

  @override
  ConsumerState<MedicalIdFormPage> createState() => _MedicalIdFormPageState();
}

class _MedicalIdFormPageState extends ConsumerState<MedicalIdFormPage> {
  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final _formKey = GlobalKey<FormState>();
  late String? _bloodType = widget.initial.bloodType;
  late DateTime? _birthDate = widget.initial.birthDate;
  late final _weight = TextEditingController(
    text: widget.initial.weightKg?.toString(),
  );
  late final _height = TextEditingController(
    text: widget.initial.heightCm?.toString(),
  );
  late final _allergies = TextEditingController(
    text: widget.initial.allergies.join(', '),
  );
  late final _conditions = TextEditingController(
    text: widget.initial.conditions.join(', '),
  );
  late final _contactName = TextEditingController(
    text: widget.initial.emergencyContact?.name,
  );
  late final _contactRelation = TextEditingController(
    text: widget.initial.emergencyContact?.relation,
  );
  late final _contactPhone = TextEditingController(
    text: widget.initial.emergencyContact?.phone,
  );
  late final _insurance = TextEditingController(text: widget.initial.insurance);
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _weight,
      _height,
      _allergies,
      _conditions,
      _contactName,
      _contactRelation,
      _contactPhone,
      _insurance,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Tanggal lahir',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  static List<String> _list(String text) =>
      text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  static String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final contactName = _text(_contactName);
    final contactPhone = _text(_contactPhone);
    final profile = widget.initial.copyWith(
      bloodType: () => _bloodType,
      birthDate: () => _birthDate,
      weightKg: () => int.tryParse(_weight.text),
      heightCm: () => int.tryParse(_height.text),
      allergies: _list(_allergies.text),
      conditions: _list(_conditions.text),
      emergencyContact: () => contactName == null || contactPhone == null
          ? null
          : EmergencyContact(
              name: contactName,
              relation: _text(_contactRelation) ?? '',
              phone: contactPhone,
            ),
      insurance: () => _text(_insurance),
    );

    setState(() => _saving = true);
    final synced = await ref
        .read(userRepositoryProvider)
        .saveMedicalProfile(profile);
    ref.invalidate(medicalProfileProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Medical ID tersimpan.'
              : 'Medical ID tersimpan di HP ini. Belum tersinkron ke server.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final birth = _birthDate;
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Medical ID')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _Label('Golongan darah'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in [..._bloodTypes, null])
                  ChoiceChip(
                    label: Text(type ?? 'Tidak tahu'),
                    selected: _bloodType == type,
                    onSelected: (_) => setState(() => _bloodType = type),
                    selectedColor: AppColors.emergencyLight,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Tanggal lahir'),
            OutlinedButton.icon(
              onPressed: _pickBirthDate,
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                birth == null
                    ? 'Pilih tanggal'
                    : '${birth.day}/${birth.month}/${birth.year}',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _NumberField(controller: _weight, label: 'Berat (kg)'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberField(
                    controller: _height,
                    label: 'Tinggi (cm)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _allergies,
              decoration: const InputDecoration(
                labelText: 'Alergi',
                hintText: 'Pisahkan dengan koma, mis. Penisilin, Udang',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _conditions,
              decoration: const InputDecoration(
                labelText: 'Kondisi / riwayat penyakit',
                hintText: 'Mis. Asma, Hipertensi',
              ),
            ),
            const SizedBox(height: 24),
            const _Label('Kontak darurat'),
            TextFormField(
              controller: _contactName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactRelation,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Hubungan',
                hintText: 'Mis. Suami, Ibu, Teman',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor telepon'),
              validator: (value) {
                final hasName = _text(_contactName) != null;
                final phone = value?.trim() ?? '';
                if (hasName && phone.isEmpty) return 'Isi nomor telepon';
                if (phone.isNotEmpty &&
                    !RegExp(r'^\+?[0-9 \-]{8,}$').hasMatch(phone)) {
                  return 'Nomor telepon tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _insurance,
              decoration: const InputDecoration(
                labelText: 'Asuransi',
                hintText: 'Mis. BPJS',
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emergency,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: InputDecoration(labelText: label),
    );
  }
}
