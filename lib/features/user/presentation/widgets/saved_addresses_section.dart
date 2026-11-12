import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/settings_list.dart';
import '../../data/address_repository.dart';
import '../../domain/saved_address.dart';
import '../providers/saved_addresses_provider.dart';

IconData savedAddressIcon(String label) => switch (label) {
  'Rumah' => Icons.home_outlined,
  'Kantor' => Icons.business_outlined,
  _ => Icons.place_outlined,
};

/// "Alamat tersimpan" in Profil: places to send an ambulance to.
class SavedAddressesSection extends ConsumerWidget {
  const SavedAddressesSection({super.key});

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    SavedAddress address,
  ) async {
    final id = address.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus "${address.label}"?'),
        content: Text(address.address),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.ambulance),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(addressRepositoryProvider).remove(id);
      ref.invalidate(savedAddressesProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Gagal menghapus alamat.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(savedAddressesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Alamat tersimpan',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => AddAddressSheet.show(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SettingsGroup(
          children: switch (addresses) {
            AsyncData(:final value) when value.isEmpty => const [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Belum ada alamat. Simpan rumah atau kantor agar bisa '
                  'memanggil ambulans ke sana dengan cepat.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
            AsyncData(:final value) => [
              for (final address in value)
                SettingsTile(
                  icon: savedAddressIcon(address.label),
                  label: address.label,
                  subtitle: address.address,
                  iconBackground: AppColors.primarySurface,
                  iconColor: AppColors.primary,
                  showChevron: false,
                  onTap: () => _remove(context, ref, address),
                ),
            ],
            AsyncError() => [
              SettingsTile(
                icon: Icons.cloud_off_rounded,
                label: 'Alamat tidak dapat dimuat',
                subtitle: 'Ketuk untuk mencoba lagi',
                color: AppColors.textSecondary,
                showChevron: false,
                onTap: () => ref.invalidate(savedAddressesProvider),
              ),
            ],
            _ => const [
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          },
        ),
      ],
    );
  }
}

/// Saves where the phone is now as "Rumah", "Kantor" or another label.
class AddAddressSheet extends ConsumerStatefulWidget {
  const AddAddressSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const AddAddressSheet(),
  );

  @override
  ConsumerState<AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<AddAddressSheet> {
  static const _labels = ['Rumah', 'Kantor', 'Lainnya'];

  String _label = _labels.first;
  final _otherLabel = TextEditingController();
  final _address = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _otherLabel.dispose();
    _address.dispose();
    super.dispose();
  }

  String get _chosenLabel =>
      _label == 'Lainnya' ? _otherLabel.text.trim() : _label;

  bool get _canSave =>
      !_saving && _chosenLabel.isNotEmpty && _address.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    // The real GPS point only: an ambulance must never be sent to a fallback.
    final position = await ref
        .read(locationServiceProvider)
        .getCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      setState(() {
        _saving = false;
        _error =
            'Lokasi GPS tidak tersedia. Nyalakan GPS dan izinkan akses '
            'lokasi, lalu coba lagi.';
      });
      return;
    }
    try {
      await ref
          .read(addressRepositoryProvider)
          .add(
            SavedAddress(
              label: _chosenLabel,
              address: _address.text.trim(),
              latitude: position.latitude,
              longitude: position.longitude,
            ),
          );
      ref.invalidate(savedAddressesProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Alamat tersimpan.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException ? e.message : 'Gagal menyimpan alamat.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simpan lokasi saat ini',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Titik GPS Anda sekarang disimpan. Lakukan ini saat Anda '
              'berada di tempat tersebut.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final label in _labels)
                  ChoiceChip(
                    avatar: Icon(savedAddressIcon(label), size: 18),
                    label: Text(label),
                    selected: _label == label,
                    onSelected: (_) => setState(() => _label = label),
                  ),
              ],
            ),
            if (_label == 'Lainnya') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherLabel,
                maxLength: 50,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Nama tempat',
                  hintText: 'mis. Rumah Ibu',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              maxLength: 500,
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Alamat lengkap',
                hintText: 'Jalan, nomor, RT/RW, patokan',
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 8),
              Text(error, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
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
