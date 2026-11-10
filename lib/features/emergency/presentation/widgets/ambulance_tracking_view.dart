import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/map/map_tiles.dart';
import '../../../../core/map/route_trim.dart';
import '../../../driver/data/routing_repository.dart';
import '../../../driver/domain/route_models.dart';
import '../../../driver/presentation/widgets/trip_map_layout.dart'
    show StableRouteOrigin;
import '../../domain/emergency_models.dart';
import '../providers/emergency_provider.dart';

/// Steps of an accepted request, from the server's `status`.
enum _Stage { toPickup, arrived, toHospital }

/// The ambulance on its way, "Ambulans telah tiba", and the drive to the
/// hospital, live on a map.
class AmbulanceTrackingView extends ConsumerStatefulWidget {
  const AmbulanceTrackingView({super.key, required this.request});

  final EmergencyRequestModel request;

  @override
  ConsumerState<AmbulanceTrackingView> createState() =>
      _AmbulanceTrackingViewState();
}

class _AmbulanceTrackingViewState extends ConsumerState<AmbulanceTrackingView>
    with StableRouteOrigin {
  final _mapController = MapController();
  bool _mapReady = false;
  bool _showFoundToast = true;
  bool _isCancelling = false;
  Timer? _toastTimer;

  /// Driving route for the current leg, once loaded.
  DriveRoute? _route;

  /// Where [_route] leads.
  LatLng? _routeTo;

  /// The route last fitted into view, so a new one is fitted once.
  DriveRoute? _fittedRoute;

  /// Toast or hospital card over the map, kept clear of the route.
  final _topKey = GlobalKey();

  EmergencyRequestModel get _request => widget.request;

  _Stage get _stage => switch (_request.status) {
        EmergencyRequestStatus.arriveAtPickup => _Stage.arrived,
        EmergencyRequestStatus.enRouteToHospital => _Stage.toHospital,
        _ => _Stage.toPickup,
      };

  LatLng get _pickup =>
      LatLng(_request.pickup.latitude, _request.pickup.longitude);

  LatLng? get _ambulance => _request.ambulance?.location;

  /// The hospital, once the ambulance is taking the patient there.
  LatLng? get _hospital {
    final hospital = _request.hospital;
    return _stage == _Stage.toHospital && hospital != null
        ? LatLng(hospital.latitude, hospital.longitude)
        : null;
  }

  @override
  void initState() {
    super.initState();
    _toastTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showFoundToast = false);
    });
  }

  @override
  void didUpdateWidget(AmbulanceTrackingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.request;
    final located = old.ambulance?.location == null && _ambulance != null;
    final hospitalKnown = old.hospital == null && _request.hospital != null;
    if (located || hospitalKnown || old.status != _request.status) _fit();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Shows the ambulance, where it is heading (the pickup point, or the
  /// hospital) and the route between them, below the card on top.
  void _fit() => WidgetsBinding.instance.addPostFrameCallback((_) => _fitNow());

  void _fitNow() {
    if (!mounted || !_mapReady) return;
    final ambulance = _ambulance ?? _pickup;
    final target = _hospital ?? _pickup;
    if (ambulance == target) {
      _mapController.move(target, 16);
      return;
    }
    // The map starts at the top of the screen, under the card.
    final top = _topKey.currentContext?.findRenderObject() as RenderBox?;
    final topEdge = top == null || !top.hasSize || top.size.height == 0
        ? 0.0
        : top.localToGlobal(Offset(0, top.size.height)).dy;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [ambulance, target, ...?_route?.points],
        // Room for the ETA chip drawn above the ambulance pin.
        padding: EdgeInsets.fromLTRB(56, topEdge + 96, 56, 56),
        maxZoom: 16.5,
      ),
    );
  }

  Future<void> _dial(String number) async {
    final opened = await launchUrl(Uri(scheme: 'tel', path: number));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka aplikasi telepon.')),
      );
    }
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelTripDialog(etaMinutes: _etaMinutes),
    );
    if (reason == null || !mounted) return;

    setState(() => _isCancelling = true);
    await ref.read(emergencyProvider.notifier).cancelRequest(reason: reason);
    if (mounted) setState(() => _isCancelling = false);
  }

  /// The road route, like the driver sees, else the server's straight-line
  /// estimate.
  DriveRoute? get _roadRoute {
    final route = _route;
    return route == null || route.isEstimate ? null : route;
  }

  int? get _etaMinutes {
    final road = _roadRoute;
    if (road != null) {
      return (road.duration.inSeconds / 60).ceil().clamp(1, 999);
    }
    final fromServer = _request.etaMinutes;
    if (fromServer != null) return fromServer;
    final route = _route;
    if (route == null) return null;
    return (route.duration.inSeconds / 60).ceil().clamp(1, 999);
  }

  double? get _distanceKm {
    final road = _roadRoute;
    if (road != null) return road.distanceMeters / 1000;
    return _request.etaDistanceKm ??
        (_route == null ? null : _route!.distanceMeters / 1000);
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;
    final ambulance = _ambulance;
    final hospital = _hospital;
    // Without a live position, the drive to the hospital starts at the pickup.
    final from = stage == _Stage.toHospital ? ambulance ?? _pickup : ambulance;
    final to = switch (stage) {
      _Stage.toPickup => _pickup,
      _Stage.arrived => null,
      _Stage.toHospital => hospital,
    };
    final loaded = from == null || to == null
        ? null
        : ref.watch(routeProvider((from: routeOrigin(from), to: to))).value;
    // While a re-route after the ambulance moved is loading, keep showing the
    // last route to the same place, so the line and ETA don't blink out.
    final route =
        _route = loaded ?? (to != null && to == _routeTo ? _route : null);
    _routeTo = to;
    if (route != null && route != _fittedRoute) {
      _fittedRoute = route;
      _fit();
    }
    final ambulanceInfo = _request.ambulance;
    final hospitalInfo = _request.hospital;
    final driverPhone = _request.assignedDriver?.phone;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _TrackingMap(
                    controller: _mapController,
                    pickup: _pickup,
                    ambulance: ambulance,
                    hospital: hospital,
                    hospitalName: hospitalInfo?.name,
                    route: route?.points ?? const <LatLng>[],
                    stage: stage,
                    etaMinutes: _etaMinutes,
                    silentSeconds: ambulanceInfo?.isSilent == true
                        ? ambulanceInfo?.locationAgeSeconds
                        : null,
                    onMapReady: () {
                      _mapReady = true;
                      _fit();
                    },
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    bottom: false,
                    minimum: const EdgeInsets.only(top: 8),
                    child: AnimatedSwitcher(
                      key: _topKey,
                      duration: const Duration(milliseconds: 250),
                      child: stage == _Stage.toHospital
                          ? hospitalInfo == null
                              ? const SizedBox.shrink()
                              : _HospitalNotice(
                                  hospital: hospitalInfo,
                                  preparation: _request.hospitalPreparation,
                                )
                          : _showFoundToast && stage == _Stage.toPickup
                              ? const _Toast(
                                  text: 'Driver ditemukan! Ambulans menuju '
                                      'lokasi Anda.',
                                )
                              : const SizedBox.shrink(),
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
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TrackingSheet(
                  request: _request,
                  stage: stage,
                  etaMinutes: _etaMinutes,
                  distanceKm: _distanceKm,
                  isCancelling: _isCancelling,
                  onCallDriver:
                      driverPhone == null ? null : () => _dial(driverPhone),
                  onCall119: () => _dial('119'),
                  onCancel: _cancel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingSheet extends StatelessWidget {
  const _TrackingSheet({
    required this.request,
    required this.stage,
    required this.etaMinutes,
    required this.distanceKm,
    required this.isCancelling,
    required this.onCallDriver,
    required this.onCall119,
    required this.onCancel,
  });

  final EmergencyRequestModel request;
  final _Stage stage;
  final int? etaMinutes;
  final double? distanceKm;
  final bool isCancelling;

  /// Null when the driver has no phone number.
  final VoidCallback? onCallDriver;
  final VoidCallback onCall119;
  final VoidCallback onCancel;

  String get _title => switch (stage) {
        _Stage.toPickup => 'Ambulans menuju lokasi Anda',
        _Stage.arrived => 'Ambulans telah tiba',
        _Stage.toHospital => 'Menuju rumah sakit',
      };

  String get _subtitle {
    final eta = [
      if (etaMinutes != null) 'Tiba dalam $etaMinutes menit',
      if (distanceKm != null) '${distanceKm!.toStringAsFixed(1)} km',
    ];
    switch (stage) {
      case _Stage.toPickup:
        return eta.isEmpty
            ? 'Tetap di tempat dan siapkan pasien'
            : eta.join(' · ');
      case _Stage.arrived:
        final plate = request.ambulance?.plateNumber;
        return plate == null
            ? 'Temui ambulans di ${request.pickup.address}'
            : 'Cari plat $plate di depan ${request.pickup.address}';
      case _Stage.toHospital:
        final hospital = request.hospital?.name;
        return [
          hospital == null ? 'Pasien sedang dibawa ke IGD' : 'Tujuan: $hospital',
          ...eta,
        ].join(' · ');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Once the ambulance is there, cancelling is no longer offered.
    final canCancel = stage == _Stage.toPickup;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        _ProgressCard(stage: stage),
        const SizedBox(height: 12),
        _DriverCard(
          driver: request.assignedDriver,
          ambulance: request.ambulance,
          onCall: onCallDriver,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _OutlineAction(
                icon: Icons.phone_in_talk_outlined,
                label: 'Telepon 119',
                color: AppColors.primary,
                onPressed: onCall119,
              ),
            ),
            if (canCancel) ...[
              const SizedBox(width: 12),
              _OutlineAction(
                icon: Icons.close_rounded,
                label: 'Batalkan',
                color: AppColors.ambulance,
                onPressed: isCancelling ? null : onCancel,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

enum _StepState { done, active, pending }

/// "Langkah 3/5" with Cari → Diterima → Jalan → Tiba → Selesai.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.stage});

  final _Stage stage;

  static const _steps = [
    (icon: Icons.search_rounded, label: 'Cari'),
    (icon: Icons.check_rounded, label: 'Diterima'),
    (icon: Icons.airport_shuttle_rounded, label: 'Jalan'),
    (icon: Icons.location_on_outlined, label: 'Tiba'),
    (icon: Icons.flag_outlined, label: 'Selesai'),
  ];

  /// Index of the current step.
  int get _current => switch (stage) {
        _Stage.toPickup => 2,
        _Stage.arrived => 3,
        _Stage.toHospital => 4,
      };

  String get _caption => switch (stage) {
        _Stage.toPickup => 'Driver menuju lokasi',
        _Stage.arrived => 'Driver tiba di lokasi',
        _Stage.toHospital => 'Menuju rumah sakit',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _caption,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                'Langkah ${_current + 1}/${_steps.length}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                _StepDot(
                  icon: i < _current ? Icons.check_rounded : _steps[i].icon,
                  state: i < _current
                      ? _StepState.done
                      : i == _current
                          ? _StepState.active
                          : _StepState.pending,
                ),
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: i < _current
                          ? AppColors.success
                          : AppColors.divider,
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < _steps.length; i++)
                SizedBox(
                  width: 56,
                  child: Text(
                    _steps[i].label,
                    textAlign: i == 0
                        ? TextAlign.left
                        : i == _steps.length - 1
                            ? TextAlign.right
                            : TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          i == _current ? FontWeight.w700 : FontWeight.w500,
                      color: i == _current
                          ? AppColors.ambulance
                          : i < _current
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.icon, required this.state});

  final IconData icon;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (state) {
      _StepState.done => (AppColors.success, Colors.white, AppColors.success),
      _StepState.active => (
          AppColors.ambulance,
          Colors.white,
          AppColors.ambulanceSurface,
        ),
      _StepState.pending => (
          AppColors.surface,
          AppColors.textHint,
          AppColors.divider,
        ),
    };
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
      ),
      child: Icon(icon, size: 16, color: foreground),
    );
  }
}

/// Driver, plate, and the Telepon button.
class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.ambulance,
    required this.onCall,
  });

  final AssignedDriver? driver;
  final AmbulanceInfo? ambulance;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final name = driver?.name ?? 'Driver ambulans';
    final plate = ambulance?.plateNumber;
    final vehicle = ambulance?.vehicleLabel;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _DriverAvatar(name: name, photoUrl: driver?.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (plate != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plate,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (vehicle != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ambulanceSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          vehicle,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ambulance,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.phone_outlined, size: 20),
              label: const Text('Telepon Driver'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final url = photoUrl;
    return CircleAvatar(
      radius: 26,
      backgroundColor: AppColors.primarySurface,
      foregroundImage: url == null ? null : NetworkImage(url),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: const BorderSide(color: AppColors.divider, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.toastSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.toastAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Batalkan pesanan ambulans?" with a reason; pops the reason, or null to
/// keep the ambulance coming.
class _CancelTripDialog extends StatefulWidget {
  const _CancelTripDialog({required this.etaMinutes});

  final int? etaMinutes;

  @override
  State<_CancelTripDialog> createState() => _CancelTripDialogState();
}

class _CancelTripDialogState extends State<_CancelTripDialog> {
  static const _reasons = [
    'Kondisi membaik',
    'Salah lokasi',
    'Pakai kendaraan lain',
    'Lainnya',
  ];

  String? _reason;

  @override
  Widget build(BuildContext context) {
    final eta = widget.etaMinutes;
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.ambulanceSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.ambulance,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Batalkan pesanan ambulans?',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${eta == null ? 'Ambulans sedang menuju lokasi Anda.' : 'Ambulans tinggal $eta menit lagi.'} '
              'Jika Anda masih membutuhkan bantuan, membatalkan dapat '
              'menunda pertolongan.',
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Alasan pembatalan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reason in _reasons)
                  ChoiceChip(
                    label: Text(reason),
                    selected: _reason == reason,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _reason = reason),
                    backgroundColor: AppColors.background,
                    selectedColor: AppColors.ambulanceSurface,
                    side: BorderSide(
                      color: _reason == reason
                          ? AppColors.ambulance
                          : AppColors.divider,
                    ),
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _reason == reason
                          ? AppColors.ambulance
                          : AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.airport_shuttle_rounded),
                label: const Text('Tetap Lanjutkan'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                // A reason is required, so the dispatcher knows why.
                onPressed: _reason == null
                    ? null
                    : () => Navigator.of(context).pop(_reason),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Ya, Batalkan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ambulance,
                  side: const BorderSide(color: AppColors.ambulanceSurface),
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
          ],
        ),
      ),
    );
  }
}

/// Pickup point, the ambulance with its ETA, and the route between them.
class _TrackingMap extends StatelessWidget {
  const _TrackingMap({
    required this.controller,
    required this.pickup,
    required this.ambulance,
    required this.hospital,
    required this.hospitalName,
    required this.route,
    required this.stage,
    required this.etaMinutes,
    required this.silentSeconds,
    required this.onMapReady,
  });

  final MapController controller;
  final LatLng pickup;
  final LatLng? ambulance;

  /// Destination of the drive to the IGD, shown once the patient is on board.
  final LatLng? hospital;
  final String? hospitalName;
  final List<LatLng> route;
  final _Stage stage;
  final int? etaMinutes;

  /// Set when the driver stopped reporting its position: how long ago.
  final int? silentSeconds;
  final VoidCallback onMapReady;

  @override
  Widget build(BuildContext context) {
    final ambulance = this.ambulance;
    final hospital = this.hospital;
    final arrived = stage == _Stage.arrived;
    final toHospital = stage == _Stage.toHospital;

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: ambulance ?? pickup,
        initialZoom: 15,
        minZoom: 5,
        maxZoom: 19,
        backgroundColor: MapTiles.background,
        onMapReady: onMapReady,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        const MapTiles(),
        if (ambulance == null)
          _routeLayer(route)
        else
          _Glide(
            to: ambulance,
            builder: (position) => _routeLayer(routeAhead(route, position)),
          ),
        if (arrived)
          CircleLayer(
            circles: [
              CircleMarker(
                point: pickup,
                radius: 60,
                useRadiusInMeter: true,
                color: AppColors.success.withValues(alpha: 0.12),
                borderColor: AppColors.success.withValues(alpha: 0.5),
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            // The patient is in the ambulance on the way to the hospital.
            if (!toHospital)
              Marker(
                point: pickup,
                width: 64,
                height: 64,
                child: const _PickupDot(),
              ),
            if (hospital != null)
              Marker(
                point: hospital,
                width: 220,
                height: 44,
                child: _HospitalChip(name: hospitalName ?? 'Rumah sakit'),
              ),
          ],
        ),
        if (ambulance != null)
          _Glide(
            to: ambulance,
            builder: (position) => MarkerLayer(
              markers: [
                Marker(
                  point: position,
                  width: 180,
                  height: 136,
                  child: _AmbulanceMarker(
                    label: silentSeconds != null
                        ? 'Sinyal driver hilang · ${_ago(silentSeconds!)}'
                        : arrived
                            ? 'Telah tiba'
                            : etaMinutes == null
                                ? null
                                : '$etaMinutes menit',
                    arrived: arrived && silentSeconds == null,
                    silent: silentSeconds != null,
                  ),
                ),
              ],
            ),
          ),
        const SimpleAttributionWidget(
          source: Text(MapTiles.attribution, style: TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  static Widget _routeLayer(List<LatLng> points) => points.length < 2
      ? const SizedBox.shrink()
      : PolylineLayer(
          polylines: [
            Polyline(points: points, strokeWidth: 5, color: AppColors.primary),
          ],
        );
}

/// Moves the ambulance (and the start of its route) smoothly to each new
/// position from the server, instead of jumping every few seconds.
class _Glide extends StatelessWidget {
  const _Glide({required this.to, required this.builder});

  /// Close to the gap between position updates, so it rarely stands still.
  static const _duration = Duration(milliseconds: 1500);

  final LatLng to;
  final Widget Function(LatLng position) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<LatLng>(
      // Starts where the marker is when [to] changes (begin is replaced).
      tween: LatLngTween(begin: to, end: to),
      duration: _duration,
      curve: Curves.easeInOut,
      builder: (context, position, _) => builder(position),
    );
  }
}

class _PickupDot extends StatelessWidget {
  const _PickupDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

/// "45 dtk", "3 mnt" or "2 jam".
String _ago(int seconds) => seconds < 90
    ? '$seconds dtk'
    : seconds < 5400
        ? '${(seconds / 60).round()} mnt'
        : '${(seconds / 3600).round()} jam';

/// Red ambulance pin with a "5 menit" / "Telah tiba" chip above it. The pin
/// is in the middle of the 136 px marker, so it sits on the point.
class _AmbulanceMarker extends StatelessWidget {
  const _AmbulanceMarker({
    required this.label,
    required this.arrived,
    this.silent = false,
  });

  final String? label;
  final bool arrived;

  /// The driver went quiet: warning colors, no moving-ambulance look.
  final bool silent;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 36,
          child: label == null
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: silent
                        ? AppColors.warning
                        : arrived
                            ? AppColors.success
                            : AppColors.toastSurface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        silent
                            ? Icons.signal_wifi_off_rounded
                            : arrived
                                ? Icons.check_circle_outline_rounded
                                : Icons.schedule_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.ambulance,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.ambulance.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.airport_shuttle_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ],
    );
  }
}

/// Labelled hospital pin at the end of the route, like the driver's map.
class _HospitalChip extends StatelessWidget {
  const _HospitalChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yellow card confirming the hospital's IGD was alerted, as the driver
/// sees it on the way there.
class _HospitalNotice extends StatelessWidget {
  const _HospitalNotice({required this.hospital, this.preparation});

  final HospitalInfo hospital;
  final String? preparation;

  @override
  Widget build(BuildContext context) {
    final entrance = hospital.ambulanceEntrance;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${hospital.name} sudah diberi tahu',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    preparation ?? 'IGD bersiap menerima pasien.',
                    if (entrance != null) 'Pintu masuk ambulans: $entrance.',
                  ].join(' '),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
