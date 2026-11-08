import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DriverShell extends ConsumerWidget {
  const DriverShell({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Portal Driver Ambulans'),
        backgroundColor: AppColors.ambulance,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.ambulanceLight,
                child: Icon(Icons.directions_car, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Selamat Datang, ${user.fullName}!',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Role: Driver Ambulans',
                  style: TextStyle(color: AppColors.ambulanceDark, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              const Card(
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Fitur ketersediaan (Online/Offline) dan penerimaan panggilan darurat akan diaktifkan di milestone berikutnya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar dari Akun'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ambulance,
                  side: const BorderSide(color: AppColors.ambulance),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

