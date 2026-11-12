import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'core/notifications/push_service.dart';
import 'features/auth/domain/auth_models.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/driver/presentation/pages/driver_shell.dart';
import 'features/user/presentation/pages/user_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Off unless Firebase settings were given at build time.
  await PushService.init();
  runApp(const ProviderScope(child: CariAmbulanApp()));
}

class CariAmbulanApp extends StatelessWidget {
  const CariAmbulanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CariAmbulan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_hospital_rounded, size: 64, color: AppColors.ambulance),
              SizedBox(height: 16),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
      error: (error, _) => const LoginPage(),
      data: (user) {
        if (user == null) {
          return const LoginPage();
        }

        if (user.isDriver) {
          return DriverShell(user: user);
        }

        if (user.isUser) {
          return UserShell(user: user);
        }

        return _UnsupportedRoleScreen(user: user);
      },
    );
  }
}

class _UnsupportedRoleScreen extends ConsumerWidget {
  const _UnsupportedRoleScreen({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 56, color: AppColors.warning),
              const SizedBox(height: 16),
              Text(
                'Akun ${user.email} (${user.roles.join(", ")}) belum didukung di aplikasi mobile.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                child: const Text('Keluar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
