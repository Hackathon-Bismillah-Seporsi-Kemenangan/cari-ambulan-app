import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/map/map_tiles.dart';
import 'core/notifications/fcm_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/auth_flow_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/call/presentation/providers/voice_call_provider.dart';
import 'features/call/presentation/widgets/active_call_sheet.dart';
import 'features/call/domain/call_models.dart';
import 'features/driver/presentation/pages/driver_shell.dart';
import 'features/user/presentation/pages/user_shell.dart';

void main() async {
  // The map reads app assets and asks Android where they are, which needs
  // the binding before runApp.
  WidgetsFlutterBinding.ensureInitialized();
  // Open the offline map while the first screen loads.
  MapTiles.preload().ignore();
  await FcmService.init();
  runApp(const ProviderScope(child: CariAmbulanApp()));
}

class CariAmbulanApp extends ConsumerWidget {
  const CariAmbulanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).asData?.value;
    return MaterialApp(
      // A session change disposes all routes, including pushed forms/trip pages.
      key: ValueKey((user?.id, user?.isDriver, user?.isUser)),
      title: 'CariAmbulan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

/// Restore the session first, then introduce signed-out users to CariAmbulan.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The other side is calling, whether the push, a poll or the lock-screen
    // launch told us: show Jawab / Tolak over whatever screen is open.
    ref.listen(voiceCallProvider, (previous, next) {
      if (next.status != VoiceCallStatus.incoming ||
          previous?.status == VoiceCallStatus.incoming) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) ActiveCallSheet.show(context);
      });
    });
    return switch (ref.watch(authProvider)) {
      AsyncData(value: null) => const AuthFlowPage(),
      AsyncData(:final value?) when value.isDriver => const DriverShell(),
      AsyncData(:final value?) when value.isUser => const UserShell(),
      AsyncData() => const _UnsupportedAccount(),
      AsyncError() => _StartupError(
        onRetry: () => ref.invalidate(authProvider),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _UnsupportedAccount extends ConsumerWidget {
  const _UnsupportedAccount();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Message(
      icon: Icons.badge_outlined,
      title: 'Akun ini belum didukung aplikasi',
      body: 'Masuk dengan akun pengguna atau akun driver ambulans.',
      action: 'Keluar',
      onAction: () => ref.read(authProvider.notifier).logout(),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Message(
      icon: Icons.wifi_off_rounded,
      title: 'Tidak dapat terhubung ke server',
      body: 'Periksa koneksi Anda, lalu coba lagi.',
      action: 'Coba Lagi',
      onAction: onRetry,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: AppColors.offline),
              const SizedBox(height: 12),
              Text(title, style: text.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(body, style: text.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(action)),
            ],
          ),
        ),
      ),
    );
  }
}
