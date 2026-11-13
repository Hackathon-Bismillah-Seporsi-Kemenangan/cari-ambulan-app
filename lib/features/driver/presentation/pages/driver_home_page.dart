import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/driver_models.dart';
import '../providers/driver_home_provider.dart';
import '../widgets/availability_card.dart';
import '../widgets/driver_home_sheet.dart';
import '../widgets/driver_map.dart';
import 'incoming_call_page.dart';
import 'to_hospital_page.dart';
import 'to_patient_page.dart';

class DriverHomePage extends ConsumerWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(driverHomeProvider)) {
      AsyncData(:final value) => _DriverHomeView(state: value),
      AsyncError() => _ErrorView(
        onRetry: () => ref.invalidate(driverHomeProvider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _DriverHomeView extends ConsumerStatefulWidget {
  const _DriverHomeView({required this.state});

  final DriverHomeState state;

  @override
  ConsumerState<_DriverHomeView> createState() => _DriverHomeViewState();
}

class _DriverHomeViewState extends ConsumerState<_DriverHomeView>
    with SingleTickerProviderStateMixin {
  // Closer, driver-focused zoom while on duty; wider overview when offline.
  static const _onlineZoom = 16.5;
  static const _offlineZoom = 15.0;

  final _mapController = MapController();
  final _topKey = GlobalKey();
  final _sheetKey = GlobalKey();
  late final AnimationController _camera;
  double _rotation = 0;
  String? _shownRequestId;

  /// GPS movement smaller than this doesn't pull the camera back.
  static const _recenterDistanceMeters = 100;

  @override
  void initState() {
    super.initState();
    _camera = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Reopen a trip that was in progress when the app was closed.
    final trip = widget.state.trip;
    if (trip != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openTrip(trip));
    }
  }

  @override
  void didUpdateWidget(_DriverHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved = const Distance().as(
      LengthUnit.Meter,
      oldWidget.state.location,
      widget.state.location,
    );
    if (oldWidget.state.isOnline != widget.state.isOnline ||
        moved > _recenterDistanceMeters) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recenter());
    }
  }

  Future<void> _openTrip(ActiveTrip trip) {
    if (!mounted) return Future.value();
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => trip.stage == TripStage.toHospital
            ? const ToHospitalPage()
            : const ToPatientPage(),
      ),
    );
  }

  @override
  void dispose() {
    _camera.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      await ref.read(driverHomeProvider.notifier).toggleOnline();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : 'Gagal mengubah status. Periksa koneksi Anda.',
          ),
        ),
      );
    }
  }

  Future<void> _showIncomingCall(EmergencyRequest request) async {
    // Only an idle, online driver can take a new call.
    final availability = ref.read(driverHomeProvider).value?.availability;
    if (availability != DriverAvailability.online) return;
    if (request.id == _shownRequestId) return;
    _shownRequestId = request.id;

    final notifier = ref.read(driverHomeProvider.notifier);
    final accepted = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => IncomingCallPage(
          request: request,
          onAccept: () => notifier.acceptRequest(request),
          onDecline: () => notifier.declineRequest(request),
        ),
      ),
    );
    if (accepted == true && mounted) {
      await Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute<void>(builder: (_) => const ToPatientPage()));
    }
  }

  /// The patient cancelled the order being served: close the trip screens
  /// (they can't be left with back) and tell the driver.
  Future<void> _onTripCancelled(ActiveTrip trip) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.popUntil((route) => route.isFirst);
    await showDialog<void>(
      context: navigator.context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cancel_outlined, color: AppColors.emergency),
        title: const Text('Order dibatalkan pasien'),
        content: Text(
          '${trip.request.reporterName} membatalkan permintaan ambulans. '
          'Anda tidak perlu melanjutkan perjalanan.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  /// Screen offset that places the driver in the middle of the map area left
  /// visible between the top card and the bottom sheet.
  Offset _focusOffset() {
    final top = _topKey.currentContext?.findRenderObject() as RenderBox?;
    final sheet = _sheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (top == null || sheet == null || !top.hasSize || !sheet.hasSize) {
      return Offset.zero;
    }
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topEdge = top.localToGlobal(Offset(0, top.size.height)).dy;
    final bottomInset = screenHeight - sheet.localToGlobal(Offset.zero).dy;
    return Offset(0, (topEdge - bottomInset) / 2);
  }

  /// Animates the camera back to the driver, north-up, like Google Maps'
  /// "my location" button.
  void _recenter({bool animate = true}) {
    if (!mounted) return;
    final target = widget.state.location;
    final zoom = widget.state.isOnline ? _onlineZoom : _offlineZoom;
    final offset = _focusOffset();

    if (!animate) {
      _mapController.rotate(0);
      _mapController.move(target, zoom, offset: offset);
      return;
    }

    final from = _mapController.camera;
    final center = LatLngTween(begin: from.center, end: target);
    final zoomTween = Tween(begin: from.zoom, end: zoom);
    // Take the short way back to north.
    final startRotation = (from.rotation + 180) % 360 - 180;
    final animation = CurvedAnimation(
      parent: _camera,
      curve: Curves.easeInOutCubic,
    );

    void tick() {
      final t = animation.value;
      _mapController.rotate(startRotation * (1 - t));
      _mapController.move(
        center.transform(t),
        zoomTween.transform(t),
        offset: offset * t,
      );
    }

    _camera
      ..stop()
      ..reset();
    animation.addListener(tick);
    _camera.forward().whenCompleteOrCancel(
      () => animation
        ..removeListener(tick)
        ..dispose(),
    );
  }

  void _onRotationChanged(double rotation) {
    final rounded = rotation % 360;
    final isNorth = rounded.abs() < 0.5 || (360 - rounded).abs() < 0.5;
    if (isNorth == (_rotation == 0)) return;
    setState(() => _rotation = isNorth ? 0 : rounded);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    ref.listen(incomingRequestProvider, (_, next) {
      if (next case AsyncData(:final value)) _showIncomingCall(value);
    });
    ref.listen(driverHomeProvider.select((s) => s.value?.cancelledTrip), (
      previous,
      cancelled,
    ) {
      if (cancelled != null && cancelled != previous) {
        _onTripCancelled(cancelled);
      }
    });

    return Stack(
      children: [
        Positioned.fill(
          child: DriverMap(
            controller: _mapController,
            location: state.location,
            isOnline: state.isOnline,
            hospital: state.nearestHospital,
            onMapReady: () => WidgetsBinding.instance.addPostFrameCallback(
              (_) => _recenter(animate: false),
            ),
            onRotationChanged: _onRotationChanged,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              key: _topKey,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AvailabilityCard(
                profile: state.profile,
                isOnline: state.isOnline,
                isBusy: state.isToggling,
                onToggle: _toggle,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(child: _Attribution()),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedScale(
                          scale: _rotation == 0 ? 0 : 1,
                          duration: const Duration(milliseconds: 200),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CompassButton(
                              rotation: _rotation,
                              onPressed: _recenter,
                            ),
                          ),
                        ),
                        _RecenterButton(onPressed: _recenter),
                      ],
                    ),
                  ],
                ),
              ),
              DriverHomeSheet(
                key: _sheetKey,
                isOnline: state.isOnline,
                stats: state.stats,
                // Scaffold.extendBody adds the floating nav to this padding.
                bottomInset: MediaQuery.paddingOf(context).bottom,
              ),
            ],
          ),
        ),
      ],
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

/// Appears when the map is rotated; tapping it returns to north-up.
class _CompassButton extends StatelessWidget {
  const _CompassButton({required this.rotation, required this.onPressed});

  final double rotation;
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
        tooltip: 'Arahkan ke utara',
        icon: Transform.rotate(
          angle: degToRadian(rotation),
          child: const Icon(
            Icons.navigation_rounded,
            color: AppColors.emergency,
          ),
        ),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Text(
      DriverMap.attribution,
      style: const TextStyle(
        fontSize: 10,
        color: AppColors.textSecondary,
        shadows: [Shadow(color: Colors.white, blurRadius: 4)],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.offline,
            ),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat data driver',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
