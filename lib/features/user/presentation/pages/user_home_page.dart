import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/logging/app_log.dart';
import '../../../../core/map/map_tiles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_models.dart';
import '../providers/user_home_providers.dart';
import '../widgets/call_ambulance_button.dart';
import '../widgets/pickup_location_card.dart';
import '../widgets/user_map.dart';
import 'searching_ambulance_page.dart';

/// "Beranda" of the user app: where am I, how far is the nearest ambulance,
/// and the one-tap emergency call.
class UserHomePage extends ConsumerStatefulWidget {
  const UserHomePage({super.key, required this.onOpenProfile});

  final VoidCallback onOpenProfile;

  @override
  ConsumerState<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends ConsumerState<UserHomePage>
    with WidgetsBindingObserver {
  final _mapController = MapController();
  bool _mapReady = false;

  /// "Memanggil untuk orang lain?": the patient isn't the caller.
  bool _forSomeoneElse = false;

  /// The search screen is on top, so a resume doesn't open it twice.
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumeOpenEmergency();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the settings with location on: look for GPS again instead
    // of staying on the fallback city.
    if (state != AppLifecycleState.resumed) return;
    final fix = ref.read(userLocationProvider).value;
    if (fix != null && fix.accuracyMeters == null) {
      ref.invalidate(userLocationProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  void _recenter(LocationFix? fix) {
    if (fix == null || !_mapReady) return;
    _mapController.move(fix.point, 15.5);
  }

  /// Shows the user and the nearest ambulance together, below the top card.
  void _fitView() {
    final fix = ref.read(userLocationProvider).value;
    final ambulance = ref.read(nearestAmbulanceProvider).value;
    if (fix == null || !_mapReady) return;
    if (ambulance == null) return _recenter(fix);
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [fix.point, ambulance.location],
        padding: const EdgeInsets.fromLTRB(64, 150, 64, 72),
        maxZoom: 16,
      ),
    );
  }

  void _onMapReady() {
    _mapReady = true;
    _fitView();
  }

  void _showMessage(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration ?? const Duration(seconds: 4),
        ),
      );
  }

  /// No real position: sending would dispatch to the wrong place, so offer
  /// to turn location on, or to call 119 instead.
  Future<void> _showNoLocation() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.location_off_outlined, color: AppColors.emergency),
      title: const Text('Lokasi tidak ditemukan'),
      content: const Text(
        'Aktifkan lokasi (GPS) agar ambulans tahu ke mana harus datang. '
        'Jika kritis, segera telepon 119.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _call119();
          },
          child: const Text('Telepon 119'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(locationServiceProvider).openSettings();
          },
          child: const Text('Aktifkan lokasi'),
        ),
      ],
    ),
  );

  Future<void> _call119() async {
    final opened = await launchUrl(Uri(scheme: 'tel', path: '119'));
    if (!opened && mounted) {
      _showMessage('Tidak dapat membuka aplikasi telepon.');
    }
  }

  /// Reopens a search that was running when the app was closed.
  Future<void> _resumeOpenEmergency() async {
    try {
      final open = await ref.read(userRepositoryProvider).fetchOpenEmergency();
      if (open != null && mounted) _openSearch(open);
    } catch (e) {
      AppLog.warn('Beranda', 'Open emergency unavailable', e);
    }
  }

  Future<void> _openSearch(EmergencySearch search) async {
    if (_isSearchOpen) return;
    _isSearchOpen = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchingAmbulancePage(initial: search),
      ),
    );
    _isSearchOpen = false;
    // Drivers' availability changed during the search, and Riwayat has a
    // new entry.
    if (mounted) {
      ref
        ..invalidate(nearestAmbulanceProvider)
        ..invalidate(emergencyHistoryProvider);
    }
  }

  Future<void> _onCallConfirmed(EmergencyType type) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    var fix = ref.read(userLocationProvider).value;
    // Without a real fix the position is the fallback city: the ambulance
    // would go to the wrong place. Ask the GPS directly before giving up.
    if (fix == null || fix.accuracyMeters == null) {
      fix = await ref.read(locationServiceProvider).currentFix();
      if (!mounted) return;
      if (fix != null) ref.invalidate(userLocationProvider);
    }
    if (fix == null) {
      Navigator.of(context).pop();
      return _showNoLocation();
    }
    final address =
        ref.read(pickupAddressProvider).value ??
        'Titik GPS ${fix.point.latitude.toStringAsFixed(5)}, '
            '${fix.point.longitude.toStringAsFixed(5)}';

    try {
      final search = await ref
          .read(userRepositoryProvider)
          .createEmergency(
            pickup: fix.point,
            address: address,
            forSelf: !_forSomeoneElse,
            type: type,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      _openSearch(search);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      // A request is still running (e.g. the user left the tracking
      // screen): reopen it instead of sending another.
      if (e is ApiException && e.isConflict) {
        await _resumeOpenEmergency();
        if (_isSearchOpen) return;
      }
      if (!mounted) return;
      // An emergency that didn't go out must not be missed.
      _showMessage(
        '${e is ApiException ? e.message : 'Gagal mengirim permintaan. Periksa koneksi lalu coba lagi.'}'
        ' Jika kritis, tekan Telepon 119.',
        duration: const Duration(seconds: 10),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fix = ref.watch(userLocationProvider).value;
    // Opening at the fallback city would load its tiles for nothing.
    final gps = fix?.accuracyMeters == null ? null : fix?.point;
    final mapStart =
        gps ?? ref.watch(savedLocationProvider).value ?? fix?.point;
    final ambulance = ref.watch(nearestAmbulanceProvider);
    final address = ref.watch(pickupAddressProvider).value;
    final name = ref.watch(authProvider).value?.fullName ?? '';

    // Frame the first GPS fix and the first ambulance found; later updates
    // only move the markers, so the user can pan freely.
    ref.listen(userLocationProvider, (previous, next) {
      final before = previous?.value;
      final now = next.value;
      // Also when GPS comes back after the fallback city was shown.
      if (now != null &&
          (before == null ||
              (before.accuracyMeters == null && now.accuracyMeters != null))) {
        _fitView();
      }
    });
    ref.listen(nearestAmbulanceProvider, (previous, next) {
      if (previous?.value == null && next.value != null) _fitView();
    });

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: mapStart == null
                    // First run, waiting for GPS.
                    ? const ColoredBox(
                        color: MapTiles.background,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : UserMap(
                        controller: _mapController,
                        location: mapStart,
                        accuracyMeters: fix?.accuracyMeters,
                        ambulance: ambulance.value,
                        onMapReady: _onMapReady,
                      ),
              ),
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                child: SafeArea(
                  bottom: false,
                  minimum: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: PickupLocationCard(
                          address: fix == null ? null : address,
                          accuracyMeters: fix?.accuracyMeters,
                          // TODO: pick another pickup point on the map.
                          onChange: () => _showMessage(
                            'Ubah lokasi jemput belum tersedia.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Avatar(name: name, onTap: widget.onOpenProfile),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 40,
                child: _RecenterButton(onPressed: _fitView),
              ),
              const Positioned(
                left: 12,
                bottom: 30,
                child: Text(
                  MapTiles.attribution,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    shadows: [Shadow(color: Colors.white, blurRadius: 4)],
                  ),
                ),
              ),
              // Rounded top of the sheet, drawn over the map.
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 24,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ColoredBox(
          color: AppColors.surface,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              // Scaffold.extendBody adds the floating nav to this padding.
              MediaQuery.paddingOf(context).bottom + 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NearestAmbulanceStatus(ambulance: ambulance),
                const SizedBox(height: 4),
                CallAmbulanceButton(onConfirmed: _onCallConfirmed),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _call119,
                    icon: const Icon(Icons.phone_in_talk_outlined),
                    label: const Text('Telepon 119'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.emergency,
                      side: const BorderSide(
                        color: AppColors.emergency,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _forSomeoneElse = !_forSomeoneElse),
                  icon: Icon(
                    _forSomeoneElse
                        ? Icons.check_circle_rounded
                        : Icons.person_add_alt_outlined,
                    size: 20,
                  ),
                  label: Text(
                    _forSomeoneElse
                        ? 'Memanggil untuk orang lain'
                        : 'Memanggil untuk orang lain?',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "● Ambulans terdekat ±4 menit" above the call button.
class _NearestAmbulanceStatus extends StatelessWidget {
  const _NearestAmbulanceStatus({required this.ambulance});

  final AsyncValue<NearestAmbulance?> ambulance;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (ambulance) {
      AsyncData(value: final a?) => (
        AppColors.online,
        'Ambulans terdekat ±${a.etaMinutes} menit',
      ),
      AsyncData() => (
        AppColors.warning,
        'Belum ada ambulans tersedia di sekitar',
      ),
      _ => (AppColors.offline, 'Mencari ambulans terdekat…'),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  String get _initials => name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Profil',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.emergency,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            _initials,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Ke lokasi saya',
        icon: const Icon(Icons.my_location_rounded, color: AppColors.primary),
      ),
    );
  }
}
