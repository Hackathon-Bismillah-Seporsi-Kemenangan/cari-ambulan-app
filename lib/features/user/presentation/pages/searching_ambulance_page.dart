import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/logging/app_log.dart';
import '../../../../core/map/map_tiles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/user_models.dart';
import '../providers/user_home_providers.dart';
import 'ambulance_tracking_view.dart';
import 'medical_id_page.dart';

/// "Mencari ambulans terdekat…": shown from the moment the emergency is sent
/// until a driver accepts or the user cancels, then follows the ambulance
/// ([AmbulanceTrackingView]) until the trip ends.
///
/// The search widens from 3 km to [SearchRadius.maxKm]; when nobody accepted
/// within that, it shows "Belum ada ambulans tersedia".
class SearchingAmbulancePage extends ConsumerStatefulWidget {
  const SearchingAmbulancePage({super.key, required this.initial});

  /// The request as created, shown until the first poll answers.
  final EmergencySearch initial;

  @override
  ConsumerState<SearchingAmbulancePage> createState() =>
      _SearchingAmbulancePageState();
}

/// Where the search is, from the server or, while it doesn't say, from the
/// app's own clock.
typedef _Progress = ({
  double radiusKm,
  Duration elapsed,
  bool exhausted,
  List<({LatLng point, double km})> ambulances,
});

class _SearchingAmbulancePageState
    extends ConsumerState<SearchingAmbulancePage> {
  static const _distance = Distance();

  bool _isCancelling = false;
  bool _isWidening = false;
  late final Timer _ticker;

  /// Opened at, when the server sends no `request_at`.
  final _openedAt = DateTime.now();

  /// Start of the local radius schedule; moved by a manual widen or a retry.
  DateTime? _scheduleStart;

  /// Last destination seen, for the handover message once the trip closes.
  String? _hospitalName;

  @override
  void initState() {
    super.initState();
    // Search timer, and the local radius schedule.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  _Progress _progressOf(EmergencySearch search) {
    final now = DateTime.now();
    final startedAt = search.requestAt?.toLocal() ?? _openedAt;
    final scheduleElapsed = now.difference(_scheduleStart ?? startedAt);
    final ambulances = [
      for (final point in search.nearbyAmbulances)
        (
          point: point,
          km: _distance.as(LengthUnit.Meter, search.pickup, point) / 1000,
        ),
    ];
    return (
      radiusKm: search.searchRadiusKm ?? SearchRadius.schedule(scheduleElapsed),
      elapsed: now.difference(startedAt),
      // Without the server's answer: the whole schedule ran and no
      // ambulance (free or ringing) is in range.
      exhausted:
          search.searchExhausted ??
          (scheduleElapsed >= SearchRadius.fullSearch &&
              ambulances.every((a) => a.km > SearchRadius.maxKm)),
      ambulances: ambulances,
    );
  }

  /// Moves the local schedule so it continues from [radiusKm].
  void _followLocally(double radiusKm) {
    final step = SearchRadius.stepsKm.indexOf(radiusKm);
    _scheduleStart = DateTime.now().subtract(
      Duration(seconds: SearchRadius.stepSeconds * math.max(step, 0)),
    );
  }

  Future<void> _widen(double radiusKm) async {
    setState(() => _isWidening = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .expandSearchRadius(widget.initial.id, radiusKm);
      ref.invalidate(emergencySearchProvider(widget.initial.id));
    } on ApiException catch (e) {
      // Older server: widen on the app's schedule only.
      AppLog.warn('Search', 'Widening locally', e);
      _followLocally(radiusKm);
    }
    if (mounted) setState(() => _isWidening = false);
  }

  Future<void> _retry() async {
    setState(() => _isWidening = true);
    try {
      await ref.read(userRepositoryProvider).retrySearch(widget.initial.id);
      ref.invalidate(emergencySearchProvider(widget.initial.id));
    } on ApiException catch (e) {
      AppLog.warn('Search', 'Retrying locally', e);
    }
    // Search the full radius once more.
    _followLocally(SearchRadius.maxKm);
    if (mounted) setState(() => _isWidening = false);
  }

  Future<void> _callEmergencyContact() async {
    final medical = (await ref.read(medicalProfileProvider.future)).value;
    final contact = medical.emergencyContact;
    if (!mounted) return;
    if (contact == null) {
      await MedicalIdPage.edit(context, medical);
      return;
    }
    await launchUrl(Uri(scheme: 'tel', path: contact.phone));
  }

  /// Leaves the search, closing any dialog on top first. Runs once: the
  /// cancel button and the polled "cancelled" status both end up here, and
  /// a second pop would close Beranda too (black screen).
  void _close() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    // Already popped, e.g. by the tracking view's own cancel.
    if (route == null || !route.isActive) return;
    Navigator.of(context)
      ..popUntil((r) => r == route)
      ..pop();
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pencarian?'),
        content: const Text(
          'Permintaan ambulans akan dihentikan. Jika kondisi kritis, '
          'segera telepon 119.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tetap Cari'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.emergency),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await ref.read(userRepositoryProvider).cancelEmergency(widget.initial.id);
      _close();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Gagal membatalkan. Coba lagi.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final search =
        ref.watch(emergencySearchProvider(widget.initial.id)).value ??
        widget.initial;

    _hospitalName = search.trip?.hospitalName ?? _hospitalName;

    // Handed over at the IGD, or cancelled elsewhere (e.g. another device):
    // nothing left to show.
    ref.listen(emergencySearchProvider(widget.initial.id), (_, next) {
      final status = next.value?.status;
      if (status == EmergencySearchStatus.completed) {
        final hospital = next.value?.trip?.hospitalName ?? _hospitalName;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hospital == null
                  ? 'Pasien telah diserahkan ke IGD. Semoga lekas sembuh!'
                  : 'Pasien telah diserahkan ke IGD $hospital. '
                        'Semoga lekas sembuh!',
            ),
          ),
        );
        _close();
      } else if (status == EmergencySearchStatus.cancelled) {
        _close();
      }
    });

    final isSearching = search.status == EmergencySearchStatus.searching;
    if (search.status == EmergencySearchStatus.found) {
      // Like the driver's trip screens: back must not drop the tracking, as
      // Beranda only picks an open request back up on the next launch.
      return PopScope(
        canPop: false,
        child: AmbulanceTrackingView(search: search),
      );
    }
    final progress = _progressOf(search);

    return PopScope(
      // Leaving must be an explicit cancel, or the search keeps running.
      canPop: !isSearching,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _SearchMap(
                      pickup: search.pickup,
                      progress: progress,
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
                  const Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: _Handle(),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: progress.exhausted
                      ? _NoAmbulanceSheet(
                          driversContacted: search.driversContacted,
                          elapsed: progress.elapsed,
                          isBusy: _isWidening || _isCancelling,
                          onRetry: _retry,
                          onCallContact: _callEmergencyContact,
                          onCancel: _cancel,
                        )
                      : _SearchingSheet(
                          driversContacted: search.driversContacted,
                          progress: progress,
                          isBusy: _isWidening || _isCancelling,
                          onWiden: _widen,
                          onCancel: _cancel,
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

String _clock(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:'
    '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Design screen 4: radius picker and how many drivers were called.
class _SearchingSheet extends StatelessWidget {
  const _SearchingSheet({
    required this.driversContacted,
    required this.progress,
    required this.isBusy,
    required this.onWiden,
    required this.onCancel,
  });

  final int driversContacted;
  final _Progress progress;
  final bool isBusy;
  final ValueChanged<double> onWiden;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final radius = progress.radiusKm;
    final inRange = progress.ambulances.where((a) => a.km <= radius).length;
    // Never fewer available than already called.
    final available = math.max(inRange, driversContacted);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mencari ambulans terdekat...',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Jangan tutup aplikasi · lokasi Anda terkirim',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Radius pencarian',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: Text(
                'Otomatis meluas tiap ${SearchRadius.stepLabel}',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _RadiusPicker(radiusKm: radius, onWiden: isBusy ? null : onWiden),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.emergencyLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$driversContacted',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emergency,
                      ),
                    ),
                    TextSpan(
                      text: '/$available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emergency.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver dihubungi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emergency,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      available == 0
                          ? 'Belum ada ambulans siaga dalam '
                                '${SearchRadius.label(radius)}'
                          : '$available ambulans siaga dalam '
                                '${SearchRadius.label(radius)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.emergencyDark,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: AppColors.emergency,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _clock(progress.elapsed),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emergency,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: isBusy ? null : onCancel,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Batalkan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.divider, width: 1.5),
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
    );
  }
}

/// "✓ 3 km | ● 5 km | 10 km": the step before, the current one and the next.
class _RadiusPicker extends StatelessWidget {
  const _RadiusPicker({required this.radiusKm, required this.onWiden});

  final double radiusKm;

  /// Null while a change is being sent.
  final ValueChanged<double>? onWiden;

  @override
  Widget build(BuildContext context) {
    const steps = SearchRadius.stepsKm;
    final current = math.max(steps.lastIndexWhere((km) => km <= radiusKm), 0);
    final first = (current - 1).clamp(0, steps.length - 3);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = first; i < first + 3; i++)
            Expanded(
              child: _RadiusOption(
                label: SearchRadius.label(steps[i]),
                state: i < current
                    ? TimelineState.done
                    : i == current
                    ? TimelineState.active
                    : TimelineState.pending,
                onTap: i > current && onWiden != null
                    ? () => onWiden!(steps[i])
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _RadiusOption extends StatelessWidget {
  const _RadiusOption({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final TimelineState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = state == TimelineState.active;
    return Semantics(
      button: onTap != null,
      selected: active,
      label: 'Radius $label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: active
              ? BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state == TimelineState.done)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (active)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.emergency,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.emergency : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Design screen 5: nobody accepted within the full radius.
class _NoAmbulanceSheet extends StatelessWidget {
  const _NoAmbulanceSheet({
    required this.driversContacted,
    required this.elapsed,
    required this.isBusy,
    required this.onRetry,
    required this.onCallContact,
    required this.onCancel,
  });

  final int driversContacted;
  final Duration elapsed;
  final bool isBusy;
  final VoidCallback onRetry;
  final VoidCallback onCallContact;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final maxRadius = SearchRadius.label(SearchRadius.maxKm);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: AppColors.warning,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Belum ada ambulans tersedia',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Semua ambulans dalam $maxRadius sedang bertugas. Jika '
                    'kondisi kritis, segera telepon 119.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _Stat(value: '$driversContacted', label: 'driver dihubungi'),
              _Stat(value: maxRadius, label: 'radius maks'),
              _Stat(value: _clock(elapsed), label: 'durasi'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: '119')),
            icon: const Icon(Icons.phone_in_talk_outlined),
            label: const Text('Telepon 119 Sekarang'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emergency,
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
          child: FilledButton.icon(
            onPressed: isBusy ? null : onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('Cari Lagi · radius $maxRadius'),
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
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onCallContact,
                  icon: const Icon(Icons.people_outline_rounded, size: 20),
                  label: const Text('Kontak darurat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.divider,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                height: 52,
                child: TextButton(
                  onPressed: isBusy ? null : onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Batalkan'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Pickup point inside the search radius rings, with the ambulances around:
/// red inside the radius, grey outside it. Zooms out as the radius grows.
class _SearchMap extends StatefulWidget {
  const _SearchMap({required this.pickup, required this.progress});

  final LatLng pickup;
  final _Progress progress;

  @override
  State<_SearchMap> createState() => _SearchMapState();
}

class _SearchMapState extends State<_SearchMap> {
  final _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(_SearchMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress.radiusKm != widget.progress.radiusKm ||
        oldWidget.progress.exhausted != widget.progress.exhausted) {
      _fit();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A point [km] north of the pickup: where a ring's label sits.
  LatLng _north(double km) =>
      LatLng(widget.pickup.latitude + km / 111.32, widget.pickup.longitude);

  /// Keeps the current ring, and a bit around it, in view.
  double get _viewKm => widget.progress.exhausted
      ? SearchRadius.maxKm
      : widget.progress.radiusKm * 1.15;

  void _fit() {
    if (!_ready) return;
    final km = _viewKm;
    final latDelta = km / 111.32;
    final lngDelta =
        km / (111.32 * math.cos(widget.pickup.latitude * math.pi / 180));
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(
            widget.pickup.latitude - latDelta,
            widget.pickup.longitude - lngDelta,
          ),
          LatLng(
            widget.pickup.latitude + latDelta,
            widget.pickup.longitude + lngDelta,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final radius = progress.radiusKm;
    final exhausted = progress.exhausted;
    const steps = SearchRadius.stepsKm;
    final current = math.max(steps.lastIndexWhere((km) => km <= radius), 0);
    // Rings up to the next step, so the user sees where the search goes.
    final rings = exhausted
        ? [SearchRadius.maxKm]
        : steps.sublist(0, math.min(current + 2, steps.length));

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: MapTiles.clamp(widget.pickup),
        initialZoom: 13,
        minZoom: MapTiles.minZoom,
        cameraConstraint: MapTiles.cameraConstraint,
        maxZoom: 19,
        backgroundColor: MapTiles.background,
        onMapReady: () {
          _ready = true;
          _fit();
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        const MapTiles(),
        CircleLayer(
          circles: [
            for (final km in rings.reversed)
              CircleMarker(
                point: widget.pickup,
                radius: km * 1000,
                useRadiusInMeter: true,
                color: exhausted
                    ? AppColors.offline.withValues(alpha: 0.06)
                    : km == steps[current]
                    ? AppColors.emergency.withValues(alpha: 0.10)
                    : AppColors.emergency.withValues(alpha: 0.03),
                borderColor: exhausted
                    ? AppColors.textSecondary
                    : km == steps[current]
                    ? AppColors.emergency
                    : AppColors.emergency.withValues(alpha: 0.35),
                borderStrokeWidth: km == steps[current] || exhausted ? 2.5 : 1,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: widget.pickup,
              width: 120,
              height: 120,
              child: _SearchPulse(isSearching: !exhausted),
            ),
            for (final ambulance in progress.ambulances)
              Marker(
                point: ambulance.point,
                width: 44,
                height: 44,
                child: _AmbulanceDot(
                  inRange: !exhausted && ambulance.km <= radius,
                ),
              ),
            // Small inner rings sit too close together to label once the
            // map zooms out: label the previous, current and next ring.
            for (final km in rings.skip(math.max(current - 1, 0)))
              Marker(
                point: _north(km),
                width: 140,
                height: 30,
                child: Center(
                  child: _RingLabel(
                    text: exhausted
                        ? '${SearchRadius.label(km)} · '
                              '${progress.ambulances.length} tersedia'
                        : SearchRadius.label(km),
                    active: !exhausted && km == steps[current],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RingLabel extends StatelessWidget {
  const _RingLabel({required this.text, required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.emergency : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? AppColors.emergency : AppColors.divider,
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// The pickup dot with a pulse while the search runs.
class _SearchPulse extends StatefulWidget {
  const _SearchPulse({required this.isSearching});

  final bool isSearching;

  @override
  State<_SearchPulse> createState() => _SearchPulseState();
}

class _SearchPulseState extends State<_SearchPulse>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isSearching) _controller.repeat();
  }

  @override
  void didUpdateWidget(_SearchPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSearching && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isSearching) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => CustomPaint(
            painter: widget.isSearching
                ? _PulsePainter(_controller.value)
                : null,
            child: child,
          ),
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = 22 + (size.width / 2 - 22) * Curves.easeOut.transform(t);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.emergency.withValues(alpha: (1 - t) * 0.6),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}

class _AmbulanceDot extends StatelessWidget {
  const _AmbulanceDot({required this.inRange});

  /// Red inside the search radius, grey outside it.
  final bool inRange;

  @override
  Widget build(BuildContext context) {
    final color = inRange ? AppColors.emergency : AppColors.offline;
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.airport_shuttle_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
