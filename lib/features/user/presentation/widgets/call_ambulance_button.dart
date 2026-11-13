import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/user_models.dart';

/// The big red "PANGGIL AMBULANS" button. Holding it for [holdDuration]
/// opens a wheel of emergency conditions around it; still holding, the
/// user slides towards one and lets go, and [onConfirmed] runs with it.
///
/// Let go in the middle and the wheel stays open to tap. With no answer
/// within [confirmSeconds] the call goes out as [EmergencyType.lainnya]
/// (the caller may not be able to answer). "Batal" sends nothing.
class CallAmbulanceButton extends StatefulWidget {
  const CallAmbulanceButton({
    super.key,
    required this.onConfirmed,
    this.holdDuration = const Duration(seconds: 2),
    this.confirmSeconds = 5,
  });

  final ValueChanged<EmergencyType> onConfirmed;
  final Duration holdDuration;
  final int confirmSeconds;

  @override
  State<CallAmbulanceButton> createState() => _CallAmbulanceButtonState();
}

class _CallAmbulanceButtonState extends State<CallAmbulanceButton>
    with TickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  /// Fills while the button is held; the wheel opens when it is full.
  late final _hold = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener(_onHoldStatus);

  /// The finger holding the button, followed onto the popup.
  int? _pointer;
  final _buttonKey = GlobalKey();

  /// The open popup's drag state; null while it is closed.
  _PickerDrag? _drag;
  OverlayEntry? _popup;

  bool get _isAsking => _drag != null;

  bool get _isHolding => _hold.isAnimating || _hold.value > 0;

  /// Let go before the ring filled: the hint says to hold longer.
  bool _tooShort = false;
  Timer? _tooShortTimer;

  /// How far the finger may drift from the button's centre while holding,
  /// e.g. with shaking hands, before the hold is dropped.
  static const _holdSlack = 112.0 + 56;

  @override
  void dispose() {
    _pulse.dispose();
    _hold.dispose();
    _tooShortTimer?.cancel();
    _popup?.remove();
    _drag?.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_isAsking || _pointer != null) return;
    _pointer = event.pointer;
    _tooShortTimer?.cancel();
    HapticFeedback.mediumImpact();
    _hold.forward(from: 0);
    setState(() => _tooShort = false);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if (_drag case final drag?) return drag.moveTo(event.position);
    // Slid well away before the ring filled: nothing is sent.
    final fromCentre = event.localPosition - const Offset(112, 112);
    if (fromCentre.distance > _holdSlack) _dropHold(hint: true);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (_drag case final drag?) return drag.release();
    // Let go too early: nothing is sent.
    _dropHold(hint: true);
  }

  /// Android took the touch away (an edge gesture, a palm): never a choice.
  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (_drag case final drag?) return drag.release(cancelled: true);
    _dropHold(hint: false);
  }

  void _dropHold({required bool hint}) {
    _pointer = null;
    _hold.reset();
    setState(() => _tooShort = hint);
    if (!hint) return;
    HapticFeedback.lightImpact();
    _tooShortTimer?.cancel();
    _tooShortTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _tooShort = false);
    });
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _ask(held: _pointer != null);
    }
  }

  /// [held]: the finger is still on the button.
  Future<void> _ask({required bool held}) async {
    HapticFeedback.heavyImpact();
    final drag = _PickerDrag(held: held);
    final button = _buttonKey.currentContext!.findRenderObject()! as RenderBox;
    final center = button.localToGlobal(button.size.center(Offset.zero));
    final answer = Completer<EmergencyType?>();
    // An overlay, not a dialog route: pushing a route cancels the finger
    // that is still holding the button.
    final popup = OverlayEntry(
      builder: (_) => _ConditionWheel(
        drag: drag,
        center: center,
        seconds: widget.confirmSeconds,
        onAnswer: answer.complete,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(popup);
    setState(() {
      _drag = drag;
      _popup = popup;
    });
    final type = await answer.future;
    if (!mounted) return;
    popup.remove();
    _hold.reset();
    setState(() {
      // Closed (back, Batal) with the first finger still down: lifting it
      // later is not a too-short press.
      _pointer = null;
      _drag = null;
      _popup = null;
    });
    drag.dispose();
    if (type != null) {
      HapticFeedback.heavyImpact();
      widget.onConfirmed(type);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back while the popup is open counts as "Batal".
      canPop: !_isAsking,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _drag?.cancel();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Panggil ambulans. Tekan dan tahan dua detik.',
            excludeSemantics: true,
            // A screen reader user can't hold: a double tap asks right away.
            onTap: _isAsking ? null : () => _ask(held: false),
            // Raw pointer events: the finger keeps reporting here after the
            // wheel opens over the button.
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: SizedBox.square(
                key: _buttonKey,
                dimension: 224,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => CustomPaint(
                          size: const Size.square(224),
                          painter: _HaloPainter(_pulse.value),
                        ),
                      ),
                    ),
                    if (_isHolding)
                      SizedBox.square(
                        dimension: 172,
                        child: AnimatedBuilder(
                          animation: _hold,
                          builder: (context, _) => CircularProgressIndicator(
                            value: _hold.value,
                            strokeWidth: 6,
                            color: AppColors.emergencyDark,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    const _Core(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _isHolding
                ? 'Terus tahan…'
                : _tooShort
                ? 'Tahan sampai lingkaran penuh'
                : 'Tekan & tahan ${widget.holdDuration.inSeconds} detik untuk '
                      'memanggil',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: _isHolding || _tooShort
                  ? FontWeight.w700
                  : FontWeight.w400,
              color: _isHolding || _tooShort
                  ? AppColors.emergency
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Passes the finger that opened the wheel (still routed to the button)
/// on to the wheel, which handles it like any later touch.
class _PickerDrag {
  /// [held] is false when nobody is holding (a screen reader opened it).
  _PickerDrag({required this.held});

  /// The opening finger is still down. Read when the wheel mounts, in case
  /// it was lifted before the first frame.
  bool held;
  _ConditionWheelState? _wheel;

  void moveTo(Offset globalPosition) => _wheel?._fingerMove(globalPosition);

  void release({bool cancelled = false}) {
    held = false;
    _wheel?._fingerUp(cancelled: cancelled);
  }

  /// Back was pressed.
  void cancel() => _wheel?._answer(null);

  void dispose() => _wheel = null;
}

/// "Apa kondisi daruratnya?": a ring of conditions around the button. The
/// finger picks the one in the direction it slides; the middle picks none.
///
/// Any touch works the same, whether the finger that held the button or a
/// new one after it was lifted by accident: the segment under the finger
/// lights up, and letting go there picks it. Letting go in the middle keeps
/// the wheel open; a tap on the middle is "Batal".
/// [onAnswer] gets the chosen [EmergencyType], [EmergencyType.lainnya] when
/// [seconds] run out after letting go, or null on "Batal" or back.
class _ConditionWheel extends StatefulWidget {
  const _ConditionWheel({
    required this.drag,
    required this.center,
    required this.seconds,
    required this.onAnswer,
  });

  final _PickerDrag drag;

  /// The button's centre, in global coordinates.
  final Offset center;
  final int seconds;
  final ValueChanged<EmergencyType?> onAnswer;

  @override
  State<_ConditionWheel> createState() => _ConditionWheelState();
}

class _ConditionWheelState extends State<_ConditionWheel> {
  static const _icons = {
    EmergencyType.kecelakaan: Icons.car_crash_rounded,
    EmergencyType.hentiJantung: Icons.monitor_heart_rounded,
    EmergencyType.sesakNafas: Icons.air_rounded,
    EmergencyType.kehamilan: Icons.pregnant_woman_rounded,
    EmergencyType.lainnya: Icons.medical_services_rounded,
  };

  /// The middle, where the finger starts: nothing is picked there.
  static const _hubRadius = 56.0;

  EmergencyType? _hovered;
  late int _secondsLeft = widget.seconds;
  Timer? _timer;
  bool _answered = false;

  /// A finger is on the screen; the countdown waits meanwhile.
  late bool _touching = widget.drag.held;

  /// The touch began on the wheel, not on the button.
  bool _newTouch = false;
  int? _pointer;
  Offset? _downAt;
  bool _moved = false;

  @override
  void initState() {
    super.initState();
    widget.drag._wheel = this;
    if (!_touching) _startCountdown();
  }

  @override
  void dispose() {
    if (widget.drag._wheel == this) widget.drag._wheel = null;
    _timer?.cancel();
    super.dispose();
  }

  /// Counts down from [_ConditionWheel.seconds] while nobody touches the
  /// wheel, so choosing isn't rushed.
  void _startCountdown() {
    _timer?.cancel();
    _secondsLeft = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) return _answer(EmergencyType.lainnya);
      HapticFeedback.selectionClick();
      setState(() => _secondsLeft--);
    });
  }

  void _fingerDown(PointerDownEvent event) {
    // One finger at a time; the opening one has priority.
    if (_touching || _answered) return;
    _timer?.cancel();
    _timer = null;
    setState(() {
      _touching = true;
      _newTouch = true;
      _pointer = event.pointer;
      _downAt = event.position;
      _moved = false;
    });
    _hover(event.position);
  }

  void _fingerMove(Offset position) {
    if (!_touching || _answered) return;
    if (_downAt case final down? when (position - down).distance > kTouchSlop) {
      _moved = true;
    }
    _hover(position);
  }

  void _hover(Offset position) {
    final hovered = _typeAt(position);
    if (hovered == _hovered) return;
    if (hovered != null) HapticFeedback.selectionClick();
    setState(() => _hovered = hovered);
  }

  void _fingerUp({bool cancelled = false}) {
    if (!_touching || _answered) return;
    final picked = _hovered;
    final tappedMiddle = _newTouch && !_moved && picked == null;
    setState(() {
      _touching = false;
      _pointer = null;
      _downAt = null;
      _hovered = null;
    });
    // A cancelled touch never picks: Android took it, the user didn't.
    if (!cancelled) {
      if (picked != null) return _answer(picked);
      if (tappedMiddle) return _answer(null);
    }
    _startCountdown();
  }

  /// The condition in the direction of [position] from the middle; how far
  /// the finger goes past the hub doesn't matter.
  EmergencyType? _typeAt(Offset position) {
    final offset = position - widget.center;
    if (offset.distance < _hubRadius) return null;
    const count = 5;
    const sweep = 2 * math.pi / count;
    // Segment 0 is centred straight up.
    final fromTop =
        (offset.direction + math.pi / 2 + sweep / 2) % (2 * math.pi);
    return EmergencyType.values[fromTop ~/ sweep % count];
  }

  void _answer(EmergencyType? type) {
    if (_answered) return;
    _answered = true;
    _timer?.cancel();
    widget.onAnswer(type);
  }

  @override
  Widget build(BuildContext context) {
    final held = _touching;
    final screen = MediaQuery.sizeOf(context);
    final radius = math.min(150.0, (screen.width - 32) / 2);
    final center = widget.center;
    final hovered = _hovered;
    // An overlay has no Material of its own: without one the text falls
    // back to the debug style.
    return Material(
      type: MaterialType.transparency,
      // Every new touch, anywhere: a tap on a segment, or a fresh slide
      // after the holding finger slipped off.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _fingerDown,
        onPointerMove: (event) {
          if (event.pointer == _pointer) _fingerMove(event.position);
        },
        onPointerUp: (event) {
          if (event.pointer == _pointer) _fingerUp();
        },
        onPointerCancel: (event) {
          if (event.pointer == _pointer) _fingerUp(cancelled: true);
        },
        child: Stack(
          children: [
            const ModalBarrier(color: Color(0xB3000000), dismissible: false),
            Positioned(
              left: 24,
              right: 24,
              bottom: screen.height - (center.dy - radius - 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Apa kondisi daruratnya?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    held
                        ? 'Geser ke kondisi pasien, lalu lepaskan.'
                        : 'Ketuk kondisi pasien. Ambulans dipanggil otomatis '
                              'dalam $_secondsLeft detik jika tidak ada jawaban.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xE6FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: center.dx - radius,
              top: center.dy - radius,
              width: radius * 2,
              height: radius * 2,
              child: _PopIn(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _WheelPainter(
                          hovered: hovered?.index,
                          innerRadius: _hubRadius,
                        ),
                      ),
                    ),
                    for (final type in EmergencyType.values)
                      _segmentLabel(type, radius),
                    Center(child: _hub(held, hovered)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Icon and name in the middle of [type]'s segment. Touches are handled
  /// by the wheel's [Listener]; screen readers tap through [Semantics].
  Widget _segmentLabel(EmergencyType type, double radius) {
    final angle = -math.pi / 2 + type.index * 2 * math.pi / 5;
    // A little past the ring's middle, so the side labels clear the hub.
    final mid = _hubRadius + (radius - _hubRadius) * 0.56;
    const size = Size(84, 76);
    final isHovered = _hovered == type;
    return Positioned(
      left: radius + mid * math.cos(angle) - size.width / 2,
      top: radius + mid * math.sin(angle) - size.height / 2,
      width: size.width,
      height: size.height,
      child: Semantics(
        button: true,
        label: type.label,
        excludeSemantics: true,
        onTap: () => _answer(type),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _icons[type],
              size: 30,
              color: isHovered ? Colors.white : AppColors.emergency,
            ),
            const SizedBox(height: 4),
            Text(
              type.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: isHovered ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The middle: the condition under the finger, else "Batal" while no
  /// finger is down.
  Widget _hub(bool held, EmergencyType? hovered) {
    final (icon, label) = switch ((held, hovered)) {
      (_, final type?) => (_icons[type]!, 'Lepas untuk\nmemanggil'),
      (true, null) => (Icons.open_with_rounded, 'Geser'),
      (false, null) => (Icons.close_rounded, 'Batal'),
    };
    return Semantics(
      button: !held,
      excludeSemantics: true,
      label: held ? null : 'Batal',
      onTap: held ? null : () => _answer(null),
      child: Container(
        width: _hubRadius * 2,
        height: _hubRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hovered != null
              ? AppColors.emergencyDark
              : AppColors.callSurface,
          border: Border.all(color: AppColors.callSurface, width: 4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Five ring segments, the [hovered] one filled red.
class _WheelPainter extends CustomPainter {
  const _WheelPainter({required this.hovered, required this.innerRadius});

  final int? hovered;
  final double innerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.width / 2;
    const count = 5;
    const sweep = 2 * math.pi / count;
    for (var i = 0; i < count; i++) {
      final start = -math.pi / 2 - sweep / 2 + i * sweep;
      final segment = Path()
        ..arcTo(
          Rect.fromCircle(center: center, radius: outer),
          start,
          sweep,
          true,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerRadius),
          start + sweep,
          -sweep,
          false,
        )
        ..close();
      canvas.drawPath(
        segment,
        Paint()..color = i == hovered ? AppColors.emergency : AppColors.surface,
      );
    }
    // Even gaps between the segments, the colour of the hub.
    final separator = Paint()
      ..color = AppColors.callSurface
      ..strokeWidth = 5;
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 - sweep / 2 + i * sweep;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * innerRadius,
        center + direction * (outer + 1),
        separator,
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.hovered != hovered || old.innerRadius != innerRadius;
}

/// Grows the wheel out from the button.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: child,
    );
  }
}

/// The red disc with the siren and label.
class _Core extends StatelessWidget {
  const _Core();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      height: 152,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE53935), AppColors.emergencyDark],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x55D32F2F),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(size: Size(30, 28), painter: _SirenPainter()),
          SizedBox(height: 8),
          Text(
            'PANGGIL\nAMBULANS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two soft rings that slowly pulse outwards around the button.
class _HaloPainter extends CustomPainter {
  const _HaloPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    final breathe = math.sin(t * 2 * math.pi) * 3;

    canvas
      ..drawCircle(
        center,
        maxRadius - 4 + breathe,
        Paint()..color = AppColors.emergency.withValues(alpha: 0.08),
      )
      ..drawCircle(
        center,
        maxRadius - 24 + breathe / 2,
        Paint()..color = AppColors.emergency.withValues(alpha: 0.12),
      )
      ..drawCircle(
        center,
        maxRadius - 24 + breathe / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.emergency.withValues(alpha: 0.25),
      );

    // One ring expanding and fading, like a beacon.
    final wave = Curves.easeOut.transform(t);
    canvas.drawCircle(
      center,
      76 + (maxRadius - 76) * wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.emergency.withValues(alpha: 0.30 * (1 - wave)),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.t != t;
}

/// Outline of an emergency light with rays, as in the design.
class _SirenPainter extends CustomPainter {
  const _SirenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;

    // Dome and base.
    final dome = Path()
      ..moveTo(w * 0.28, h * 0.84)
      ..lineTo(w * 0.28, h * 0.58)
      ..arcToPoint(
        Offset(w * 0.72, h * 0.58),
        radius: Radius.circular(w * 0.22),
      )
      ..lineTo(w * 0.72, h * 0.84);
    canvas
      ..drawPath(dome, paint)
      ..drawLine(Offset(w * 0.16, h * 0.92), Offset(w * 0.84, h * 0.92), paint)
      ..drawLine(Offset(w * 0.5, h * 0.6), Offset(w * 0.5, h * 0.76), paint);

    // Rays.
    for (final (from, to) in [
      (Offset(w * 0.5, h * 0.04), Offset(w * 0.5, h * 0.16)),
      (Offset(w * 0.16, h * 0.16), Offset(w * 0.24, h * 0.26)),
      (Offset(w * 0.84, h * 0.16), Offset(w * 0.76, h * 0.26)),
      (Offset(w * 0.02, h * 0.46), Offset(w * 0.12, h * 0.48)),
      (Offset(w * 0.98, h * 0.46), Offset(w * 0.88, h * 0.48)),
    ]) {
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_SirenPainter old) => false;
}
