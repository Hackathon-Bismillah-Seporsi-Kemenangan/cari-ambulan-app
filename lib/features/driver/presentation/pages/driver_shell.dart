import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/alerts/emergency_alert.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/notifications/push_service.dart';
import '../../../../core/widgets/pill_bottom_nav.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../call/domain/call_models.dart';
import '../../../call/presentation/providers/voice_call_provider.dart';
import '../../../call/presentation/widgets/active_call_screen.dart';
import '../providers/driver_home_provider.dart';
import '../providers/driver_offer_provider.dart';
import '../providers/driver_trip_provider.dart';
import 'driver_history_page.dart';
import 'driver_home_page.dart';
import 'driver_profile_page.dart';
import 'incoming_call_page.dart';
import 'trip_navigation_page.dart';

/// Root of the driver role: tabs Beranda / Riwayat / Profil.
///
/// Calls and trips are watched here, so they open whichever tab is shown.
class DriverShell extends ConsumerStatefulWidget {
  const DriverShell({super.key, required this.user});

  final AuthUser user;

  @override
  ConsumerState<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends ConsumerState<DriverShell> {
  int _index = 0;

  /// Tabs are built on first visit, so Riwayat doesn't load at startup.
  final _visited = {0};

  late final VoiceCallNotifier _calls;
  StreamSubscription<PushKind>? _pushes;

  @override
  void initState() {
    super.initState();
    _calls = ref.read(voiceCallProvider.notifier);
    // The patient can call while a trip is on.
    ref.listenManual<DriverTripState>(
      driverTripProvider,
      (_, next) => _calls.watchIncoming(
        next.hasActiveTrip,
        peerRole: 'Pasien / Keluarga',
      ),
      fireImmediately: true,
    );
    // A push is only a nudge: ask the server now instead of on the next poll.
    _pushes = PushService.messages.listen((kind) {
      switch (kind) {
        case PushKind.incomingCall:
          _calls.checkIncoming();
        case PushKind.emergencyOffer:
          ref.read(driverOfferProvider.notifier).pollNow();
      }
    });
  }

  @override
  void dispose() {
    _pushes?.cancel();
    // Signed out: stop asking the server for calls.
    Future.microtask(() => _calls.watchIncoming(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Jawab / Tolak over the map; once picked up, the call goes on in the
    // bar on the trip sheet.
    ref.listen<VoiceCallState>(voiceCallProvider, (prev, next) {
      if (next.status == VoiceCallStatus.incoming &&
          prev?.status != VoiceCallStatus.incoming) {
        ActiveCallScreen.show(context, closeOnAnswer: true);
      }
    });

    ref.listen<AsyncValue<DriverHomeState>>(driverHomeProvider, (prev, next) {
      final isOnline = next.value?.profile.isOnline ?? false;
      final wasOnline = prev?.value?.profile.isOnline ?? false;
      if (isOnline && !wasOnline) {
        // Asks for the notification permission before the first call rings.
        EmergencyAlert.init();
        ref.read(driverOfferProvider.notifier).startPolling();
      } else if (!isOnline && wasOnline) {
        ref.read(driverOfferProvider.notifier).stopPolling();
      }
    });

    // Ring the driver full-screen for each new offer.
    ref.listen<DriverOfferState>(driverOfferProvider, (prev, next) {
      final offer = next.offer;
      if (!(prev?.hasOffer ?? false) && next.hasOffer && offer != null) {
        IncomingCallPage.open(context, offer);
      }
    });

    // Open navigation when a trip starts: just accepted, or resumed after
    // the app was closed mid-trip.
    ref.listen<DriverTripState>(driverTripProvider, (prev, next) {
      if (!(prev?.hasActiveTrip ?? false) && next.hasActiveTrip) {
        TripNavigationPage.open(context);
      }
    });

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          DriverHomePage(user: widget.user),
          if (_visited.contains(1))
            const DriverHistoryPage()
          else
            const SizedBox.shrink(),
          if (_visited.contains(2))
            const DriverProfilePage()
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: PillBottomNav(
        items: const [
          (icon: Icons.home_outlined, label: 'Beranda'),
          (icon: Icons.history_rounded, label: 'Riwayat'),
          (icon: Icons.person_outline_rounded, label: 'Profil'),
        ],
        currentIndex: _index,
        color: AppColors.ambulance,
        selectedBackground: AppColors.ambulanceSurface,
        onTap: (i) {
          // Show trips finished since the list was last loaded.
          if (i == 1 && i != _index) ref.invalidate(driverTripHistoryProvider);
          setState(() {
            _index = i;
            _visited.add(i);
          });
        },
      ),
    );
  }
}
