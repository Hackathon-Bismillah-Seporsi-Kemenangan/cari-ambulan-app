import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shrinking ring with the seconds left to accept an emergency call.
///
/// Counts down to [expiresAt] (server time) rather than a local duration, so
/// a call that arrived late shows the real remaining time.
class CallCountdown extends StatefulWidget {
  const CallCountdown({
    super.key,
    required this.expiresAt,
    required this.total,
    this.onExpired,
  });

  final DateTime expiresAt;
  final Duration total;

  /// Called once when the time runs out. Null while the driver's response is
  /// being sent, so an expiry can't race an accept.
  final VoidCallback? onExpired;

  @override
  State<CallCountdown> createState() => _CallCountdownState();
}

class _CallCountdownState extends State<CallCountdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    final remaining = widget.expiresAt.difference(DateTime.now());
    final totalMs = widget.total.inMilliseconds;
    final startValue = totalMs <= 0
        ? 1.0
        : (1 - remaining.inMilliseconds / totalMs).clamp(0.0, 1.0);

    _controller = AnimationController(vsync: this, duration: widget.total)
      ..value = startValue
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _expire();
      })
      ..forward();
    if (startValue >= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _expire());
    }
  }

  @override
  void didUpdateWidget(CallCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The callback was re-enabled after the deadline passed (e.g. a failed
    // accept), so treat the call as expired now.
    if (oldWidget.onExpired == null && _controller.isCompleted) _expire();
  }

  void _expire() {
    final onExpired = widget.onExpired;
    if (_expired || onExpired == null) return;
    _expired = true;
    onExpired();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 140,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final remainingFraction = 1 - _controller.value;
            final seconds =
                (widget.total.inMilliseconds * remainingFraction / 1000).ceil();

            return CustomPaint(
              painter: _RingPainter(progress: remainingFraction),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$seconds',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'detik',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  /// 1 = full ring, 0 = empty.
  final double progress;

  static const _stroke = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    final arc = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(rect, track);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
