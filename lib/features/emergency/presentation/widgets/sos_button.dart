import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/emergency_models.dart';
import '../providers/emergency_provider.dart';

/// A place the ambulance can be sent instead of the phone's position.
typedef SavedPlace = ({String label, EmergencyLocation location});

class SosButton extends ConsumerStatefulWidget {
  const SosButton({super.key, this.savedPlaces = const []});

  /// Offered in the confirmation as "Kirim ke"; empty shows no choice.
  final List<SavedPlace> savedPlaces;

  @override
  ConsumerState<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends ConsumerState<SosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showSosConfirmation(BuildContext context) {
    String selectedType = 'Darurat Umum';
    final notesController = TextEditingController();
    // Null sends the ambulance to where the phone is.
    SavedPlace? selectedPlace;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Panggil Ambulans Darurat',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pilih jenis kegawatdaruratan medis agar tim medis dapat mempersiapkan peralatan yang tepat:',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(
                        label: '🚨 Darurat Umum',
                        selected: selectedType == 'Darurat Umum',
                        onTap: () => setModalState(() => selectedType = 'Darurat Umum'),
                      ),
                      _buildChip(
                        label: '❤️ Serangan Jantung / Nyeri Dada',
                        selected: selectedType == 'Jantung',
                        onTap: () => setModalState(() => selectedType = 'Jantung'),
                      ),
                      _buildChip(
                        label: '🩹 Kecelakaan / Trauma',
                        selected: selectedType == 'Trauma/Kecelakaan',
                        onTap: () => setModalState(() => selectedType = 'Trauma/Kecelakaan'),
                      ),
                      _buildChip(
                        label: '🤰 Kebidanan / Melahirkan',
                        selected: selectedType == 'Kebidanan',
                        onTap: () => setModalState(() => selectedType = 'Kebidanan'),
                      ),
                    ],
                  ),
                  if (widget.savedPlaces.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Kirim ambulans ke:',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(
                          label: '📍 Lokasi saya sekarang',
                          selected: selectedPlace == null,
                          onTap: () =>
                              setModalState(() => selectedPlace = null),
                        ),
                        for (final place in widget.savedPlaces)
                          _buildChip(
                            label: place.label,
                            selected: selectedPlace == place,
                            onTap: () =>
                                setModalState(() => selectedPlace = place),
                          ),
                      ],
                    ),
                    if (selectedPlace case final place?) ...[
                      const SizedBox(height: 6),
                      Text(
                        place.location.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'Catatan tambahan kondisi pasien (opsional)',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(emergencyProvider.notifier).triggerSOS(
                            emergencyType: selectedType,
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                            pickup: selectedPlace?.location,
                          );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'PANGGIL SEKARANG (SOS)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.error.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.error : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppColors.error : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: GestureDetector(
        onTap: () => _showSosConfirmation(context),
        child: Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFC62828)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53935).withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 6,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emergency, size: 52, color: Colors.white),
              SizedBox(height: 6),
              Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'DARURAT',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

