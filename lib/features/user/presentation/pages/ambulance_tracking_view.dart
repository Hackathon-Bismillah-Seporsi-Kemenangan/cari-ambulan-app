import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/map/map_tiles.dart';
import '../../../../core/map/route_trim.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../call/presentation/providers/voice_call_provider.dart';
import '../../../call/presentation/widgets/active_call_sheet.dart';
import '../../../driver/domain/route_models.dart';
import '../../../driver/presentation/providers/driver_home_provider.dart'
    show routeProvider;
import '../../../driver/presentation/widgets/trip_map_layout.dart'
    show StableRouteOrigin;
import '../../domain/user_models.dart';
import '../providers/user_home_providers.dart';

/// Design screens 6–9: the ambulance on its way, the cancel dialog,
/// "Ambulans telah tiba", and the drive to the hospital.
class AmbulanceTrackingView extends ConsumerStatefulWidget {
  const AmbulanceTrackingView({super.key, required this.search});

  final EmergencySearch search;

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

  EmergencySearch get _search => widget.search;
  TripInfo? get _trip => _search.trip;

  /// The hospital, once the ambulance is taking the patient there.
  LatLng? get _hospital =>
      _search.stage == TripStage.toHospital ? _trip?.hospitalLocation : null;

  @override
  void initState() {
    super.initState();
    _toastTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showFoundToast = false);
    });
    // The driver calling: ring with Jawab / Tolak.
    ref.listenManual(incomingCallProvider, (_, next) {
      final call = next.value;
      if (call == null || !mounted) return;
      if (ref.read(voiceCallProvider.notifier).receiveCall(call)) {
        ActiveCallSheet.show(context);
      }
    });
  }

  @override
  void didUpdateWidget(AmbulanceTrackingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.search.trip;
    final moved =
        old?.ambulanceLocation == null && _trip?.ambulanceLocation != null;
    final hospitalKnown =
        old?.hospitalLocation == null && _trip?.hospitalLocation != null;
    if (moved || hospitalKnown || oldWidget.search.stage != _search.stage) {
      _fit();
    }
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
    final ambulance = _trip?.ambulanceLocation ?? _search.pickup;
    final target = _hospital ?? _search.pickup;
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _callDriver() async {
    final driverName = _trip?.driverName ?? 'Driver Ambulans';
    ActiveCallSheet.show(context);
    try {
      // startCall creates the call itself; posting it here too made the
      // second request fail with "masih ada panggilan yang berlangsung".
      await ref
          .read(voiceCallProvider.notifier)
          .startCall(emergencyRequestId: _search.id, peerName: driverName);
    } catch (e) {
      if (mounted) {
        _showMessage(
          e is ApiException ? e.message : 'Gagal menghubungi driver.',
        );
      }
    }
  }

  Future<void> _share() async {
    final trip = _trip;
    final pickup = _search.pickup;
    final link =
        trip?.shareUrl ??
        'https://maps.google.com/?q=${pickup.latitude},${pickup.longitude}';
    final plate = trip?.plateNumber == null ? '' : ' (${trip!.plateNumber})';
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Saya sedang dijemput ambulans CariAmbulan$plate di '
            '${_search.pickupAddress}. Pantau lokasinya: $link',
      ),
    );
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelTripDialog(etaMinutes: _etaMinutes),
    );
    if (reason == null || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .cancelEmergency(_search.id, reason: reason);
      // The search page may already have closed on the polled status.
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      _showMessage(
        e is ApiException ? e.message : 'Gagal membatalkan. Coba lagi.',
      );
    }
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
    final fromServer = _trip?.etaMinutes;
    if (fromServer != null) return fromServer;
    final route = _route;
    if (route == null) return null;
    return (route.duration.inSeconds / 60).ceil().clamp(1, 999);
  }

  double? get _distanceKm {
    final route = _roadRoute ?? (_trip?.distanceKm == null ? _route : null);
    return route == null ? _trip?.distanceKm : route.distanceMeters / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final stage = _search.stage;
    final ambulance = _trip?.ambulanceLocation;
    final hospital = _hospital;
    // Without a live position, the drive to the hospital starts at the pickup.
    final from = stage == TripStage.toHospital
        ? ambulance ?? _search.pickup
        : ambulance;
    final to = switch (stage) {
      TripStage.toPickup => _search.pickup,
      TripStage.arrived => null,
      TripStage.toHospital => hospital,
    };
    final loaded = from == null || to == null
        ? null
        : ref.watch(routeProvider((from: routeOrigin(from), to: to))).value;
    // While a re-route after the ambulance moved is loading, keep showing the
    // last route to the same place, so the line and ETA don't blink out.
    final route = _route =
        loaded ?? (to != null && to == _routeTo ? _route : null);
    _routeTo = to;
    if (route != null && route != _fittedRoute) {
      _fittedRoute = route;
      _fit();
    }
    final trip = _trip;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _TrackingMap(
                    controller: _mapController,
                    pickup: _search.pickup,
                    ambulance: ambulance,
                    hospital: hospital,
                    hospitalName: trip?.hospitalName,
                    route: route?.points ?? const <LatLng>[],
                    stage: stage,
                    etaMinutes: _etaMinutes,
                    silentSeconds: trip?.driverSilent == true
                        ? trip?.locationAgeSeconds
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
                      child: stage == TripStage.toHospital
                          ? trip?.hospitalName == null
                                ? const SizedBox.shrink()
                                : _HospitalNotice(trip: trip!)
                          : _showFoundToast && stage == TripStage.toPickup
                          ? const _Toast(
                              text:
                                  'Driver ditemukan! Ambulans menuju lokasi '
                                  'Anda.',
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
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
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
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
                  search: _search,
                  etaMinutes: _etaMinutes,
                  distanceKm: _distanceKm,
                  isCancelling: _isCancelling,
                  onCall: _callDriver,
                  onChat: () =>
                      _showMessage('Chat dengan driver belum tersedia.'),
                  onShare: _share,
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
    required this.search,
    required this.etaMinutes,
    required this.distanceKm,
    required this.isCancelling,
    required this.onCall,
    required this.onChat,
    required this.onShare,
    required this.onCancel,
  });

  final EmergencySearch search;
  final int? etaMinutes;
  final double? distanceKm;
  final bool isCancelling;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onShare;
  final VoidCallback onCancel;

  String get _title => switch (search.stage) {
    TripStage.toPickup => 'Ambulans menuju lokasi Anda',
    TripStage.arrived => 'Ambulans telah tiba',
    TripStage.toHospital => 'Menuju rumah sakit',
  };

  String get _subtitle {
    final trip = search.trip;
    switch (search.stage) {
      case TripStage.toPickup:
        final parts = [
          if (etaMinutes != null) 'Tiba dalam $etaMinutes menit',
          if (distanceKm != null) '${distanceKm!.toStringAsFixed(1)} km',
        ];
        return parts.isEmpty
            ? 'Tetap di tempat dan siapkan pasien'
            : parts.join(' · ');
      case TripStage.arrived:
        final plate = trip?.plateNumber;
        return plate == null
            ? 'Temui ambulans di ${search.pickupAddress}'
            : 'Cari plat $plate di depan ${search.pickupAddress}';
      case TripStage.toHospital:
        final hospital = trip?.hospitalName;
        final parts = [
          hospital == null
              ? 'Pasien sedang dibawa ke IGD'
              : 'Tujuan: $hospital',
          if (etaMinutes != null) 'Tiba dalam $etaMinutes menit',
          if (distanceKm != null) '${distanceKm!.toStringAsFixed(1)} km',
        ];
        return parts.join(' · ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCancel = search.stage == TripStage.toPickup;

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
        _ProgressCard(stage: search.stage),
        const SizedBox(height: 12),
        _DriverCard(trip: search.trip, onCall: onCall, onChat: onChat),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _OutlineAction(
                icon: Icons.share_outlined,
                label: 'Bagikan lokasi live',
                color: AppColors.primary,
                onPressed: onShare,
              ),
            ),
            if (canCancel) ...[
              const SizedBox(width: 12),
              _OutlineAction(
                icon: Icons.close_rounded,
                label: 'Batalkan',
                color: AppColors.emergency,
                onPressed: isCancelling ? null : onCancel,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// "Langkah 3/5" with Cari → Diterima → Jalan → Tiba → Selesai.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.stage});

  final TripStage stage;

  static const _steps = [
    (icon: Icons.search_rounded, label: 'Cari'),
    (icon: Icons.check_rounded, label: 'Diterima'),
    (icon: Icons.airport_shuttle_rounded, label: 'Jalan'),
    (icon: Icons.location_on_outlined, label: 'Tiba'),
    (icon: Icons.flag_outlined, label: 'Selesai'),
  ];

  /// Index of the current step.
  int get _current => switch (stage) {
    TripStage.toPickup => 2,
    TripStage.arrived => 3,
    TripStage.toHospital => 4,
  };

  String get _caption => switch (stage) {
    TripStage.toPickup => 'Driver menuju lokasi',
    TripStage.arrived => 'Driver tiba di lokasi',
    TripStage.toHospital => 'Menuju rumah sakit',
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
                      ? TimelineState.done
                      : i == _current
                      ? TimelineState.active
                      : TimelineState.pending,
                ),
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: i < _current
                          ? AppColors.online
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
                      fontWeight: i == _current
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: i == _current
                          ? AppColors.emergency
                          : i < _current
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
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

enum TimelineState { done, active, pending }

class _StepDot extends StatelessWidget {
  const _StepDot({required this.icon, required this.state});

  final IconData icon;
  final TimelineState state;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (state) {
      TimelineState.done => (AppColors.online, Colors.white, AppColors.online),
      TimelineState.active => (
        AppColors.emergency,
        Colors.white,
        AppColors.emergencyLight,
      ),
      TimelineState.pending => (
        AppColors.surface,
        AppColors.textMuted,
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

/// Driver, plate, and the Telepon / Chat buttons.
class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.trip,
    required this.onCall,
    required this.onChat,
  });

  final TripInfo? trip;
  final VoidCallback onCall;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final trip = this.trip;
    final name = trip?.driverName ?? 'Driver ambulans';
    final rating = trip?.driverRating;
    final trips = trip?.driverTripCount;
    final stats = [
      if (rating != null) rating.toStringAsFixed(1),
      if (trips != null) '${_thousands(trips)} trip',
    ].join(' · ');

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
              _DriverAvatar(name: name, photoUrl: trip?.driverPhotoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (stats.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (rating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: Color(0xFFF5A623),
                            ),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              stats,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (trip?.plateNumber != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      trip!.plateNumber!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (trip.vehicleLabel != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.emergencyLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trip.vehicleLabel!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emergency,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone_outlined, size: 20),
                    label: const Text('Telepon'),
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
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onChat,
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 20,
                    ),
                    label: const Text('Chat'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: AppColors.primary,
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _thousands(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
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
      backgroundColor: AppColors.primaryLight,
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
        color: AppColors.callSurface,
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
            color: AppColors.callAccent,
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.emergencyLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.emergency,
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
                    selectedColor: AppColors.emergencyLight,
                    side: BorderSide(
                      color: _reason == reason
                          ? AppColors.emergency
                          : AppColors.divider,
                    ),
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _reason == reason
                          ? AppColors.emergency
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
                  foregroundColor: AppColors.emergency,
                  side: const BorderSide(color: AppColors.emergencyLight),
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
  final TripStage stage;
  final int? etaMinutes;

  /// Set when the driver stopped reporting its position: how long ago.
  final int? silentSeconds;
  final VoidCallback onMapReady;

  @override
  Widget build(BuildContext context) {
    final ambulance = this.ambulance;
    final hospital = this.hospital;
    final arrived = stage == TripStage.arrived;
    final toHospital = stage == TripStage.toHospital;

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: MapTiles.clamp(ambulance ?? pickup),
        initialZoom: 15,
        minZoom: MapTiles.minZoom,
        cameraConstraint: MapTiles.cameraConstraint,
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
                color: AppColors.online.withValues(alpha: 0.12),
                borderColor: AppColors.online.withValues(alpha: 0.5),
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

/// Red ambulance pin with a "5 menit" / "Telah tiba" chip above it. The pin
/// is in the middle of the 136 px marker, so it sits on the point.
String _ago(int seconds) => seconds < 90
    ? '$seconds dtk'
    : seconds < 5400
    ? '${(seconds / 60).round()} mnt'
    : '${(seconds / 3600).round()} jam';

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
                        ? AppColors.online
                        : AppColors.callSurface,
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
            color: AppColors.emergency,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.emergency.withValues(alpha: 0.35),
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
                color: AppColors.online,
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
  const _HospitalNotice({required this.trip});

  final TripInfo trip;

  @override
  Widget build(BuildContext context) {
    final entrance = trip.hospitalEntrance;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
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
                  '${trip.hospitalName} sudah diberi tahu',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    trip.hospitalPreparation ?? 'IGD bersiap menerima pasien.',
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
