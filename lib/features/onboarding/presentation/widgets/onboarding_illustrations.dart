import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Onboarding illustrations, drawn as vectors on a 300x300 canvas (the
/// slide scales and clips them into its tinted circle). They are static so
/// the slides settle; the page supplies the parallax.

const _ink = Color(0xFF1B2A4A);
const _inkSoft = Color(0xFF2B3C60);
const _red = Color(0xFFD32F2F);
const _blue = Color(0xFF1565C0);
const _green = Color(0xFF2E9E57);
const _sky = Color(0xFF8EC5F2);
const _line = Color(0xFFCBD8E6);
const _mute = Color(0xFFB6C2D2);
const _mapLand = Color(0xFFEAF1F7);

const _canvas = Size(300, 300);

/// Patient 1 — one press-and-hold button sends help and the location.
class SosIllustration extends StatelessWidget {
  const SosIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: _canvas, painter: _SosPainter());
}

/// Patient 2 — the nearest standby ambulance is found automatically.
class NearestAmbulanceIllustration extends StatelessWidget {
  const NearestAmbulanceIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: _canvas, painter: _NearestPainter());
}

/// Patient 3 — live map with the ambulance, ETA and a call button.
class TrackingIllustration extends StatelessWidget {
  const TrackingIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: _canvas, painter: _TrackingPainter());
}

/// Driver 1 — a loud emergency order with a 30 second countdown.
class OrderAlertIllustration extends StatelessWidget {
  const OrderAlertIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: _canvas, painter: _OrderAlertPainter());
}

/// Driver 2 — the route from the patient to the hospital.
class HospitalRouteIllustration extends StatelessWidget {
  const HospitalRouteIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: _canvas, painter: _HospitalRoutePainter());
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared drawing helpers
// ─────────────────────────────────────────────────────────────────────────────

Paint _fill(Color color) => Paint()
  ..color = color
  ..isAntiAlias = true;

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

RRect _rr(Rect rect, double radius) =>
    RRect.fromRectAndRadius(rect, Radius.circular(radius));

void _bar(Canvas c, double x, double y, double w, double h, Color color) {
  c.drawRRect(_rr(Rect.fromLTWH(x, y, w, h), h / 2), _fill(color));
}

void _shadow(Canvas c, RRect shape, {double blur = 8, double dy = 5}) {
  c.drawRRect(
    shape.shift(Offset(0, dy)),
    Paint()
      ..color = _ink.withAlpha(36)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
  );
}

/// A floating white card with a soft shadow.
void _card(Canvas c, Rect rect, double radius) {
  final shape = _rr(rect, radius);
  _shadow(c, shape);
  c.drawRRect(shape, _fill(Colors.white));
}

void _cross(Canvas c, Offset center, double size, Color color) {
  final thick = size * 0.34;
  final corner = thick * 0.26;
  final paint = _fill(color);
  c.drawRRect(
    _rr(Rect.fromCenter(center: center, width: size, height: thick), corner),
    paint,
  );
  c.drawRRect(
    _rr(Rect.fromCenter(center: center, width: thick, height: size), corner),
    paint,
  );
}

/// A map pin whose point sits on [tip].
void _pin(Canvas c, Offset tip, double height, Color color) {
  final r = height * 0.36;
  final cy = tip.dy - height + r;
  final path = Path()
    ..moveTo(tip.dx, tip.dy)
    ..quadraticBezierTo(tip.dx - r, tip.dy - height * 0.42, tip.dx - r, cy)
    ..arcToPoint(Offset(tip.dx + r, cy), radius: Radius.circular(r))
    ..quadraticBezierTo(tip.dx + r, tip.dy - height * 0.42, tip.dx, tip.dy)
    ..close();
  c.drawPath(path, _fill(color));
  c.drawCircle(Offset(tip.dx, cy), r * 0.4, _fill(Colors.white));
}

void _dashed(
  Canvas c,
  Path path,
  Paint paint, {
  double on = 6,
  double off = 7,
}) {
  for (final metric in path.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      c.drawPath(metric.extractPath(d, d + on), paint);
      d += on + off;
    }
  }
}

void _text(
  Canvas c,
  String text,
  Offset center, {
  required double size,
  Color color = _ink,
  FontWeight weight = FontWeight.w800,
  double spacing = 0,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1,
        letterSpacing: spacing,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(c, center - Offset(painter.width / 2, painter.height / 2));
}

void _icon(Canvas c, IconData icon, Offset center, double size, Color color) {
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: size,
        color: color,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(c, center - Offset(painter.width / 2, painter.height / 2));
}

/// A phone; [content] paints inside the clipped screen.
void _phone(
  Canvas c,
  Rect frame,
  void Function(Canvas c, Rect screen) content, {
  Color screenColor = Colors.white,
}) {
  const radius = 22.0;
  final body = _rr(frame, radius);
  _shadow(c, body, blur: 10, dy: 8);
  c.drawRRect(body, _fill(_ink));

  final screen = frame.deflate(5);
  c.save();
  c.clipRRect(_rr(screen, radius - 5));
  c.drawRect(screen, _fill(screenColor));
  content(c, screen);
  c.restore();

  // Speaker notch.
  c.drawRRect(
    RRect.fromRectAndCorners(
      Rect.fromCenter(
        center: Offset(frame.center.dx, screen.top + 3.5),
        width: frame.width * 0.3,
        height: 7,
      ),
      bottomLeft: const Radius.circular(6),
      bottomRight: const Radius.circular(6),
    ),
    _fill(_ink),
  );
}

/// A round map marker for an ambulance seen from above.
void _ambulanceMarker(
  Canvas c,
  Offset center,
  double radius, {
  bool active = true,
}) {
  c.drawCircle(
    center + const Offset(0, 2),
    radius,
    Paint()
      ..color = _ink.withAlpha(40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );
  c.drawCircle(center, radius, _fill(Colors.white));
  if (active) {
    c.drawCircle(center, radius - 1.5, _stroke(_red, 3));
  } else {
    c.drawCircle(center, radius - 0.75, _stroke(_line, 1.5));
  }
  _cross(c, center, radius * 0.95, active ? _red : _mute);
}

/// Side view of an ambulance facing right. Unscaled it is 150 wide and its
/// wheels touch the ground at y = 74.
void _ambulance(Canvas c, Offset origin, double scale) {
  c.save();
  c.translate(origin.dx, origin.dy);
  c.scale(scale);

  c.drawOval(const Rect.fromLTWH(8, 69, 138, 9), _fill(_ink.withAlpha(30)));

  final body = Path()
    ..moveTo(8, 8)
    ..lineTo(92, 8)
    ..quadraticBezierTo(98, 8, 98, 14)
    ..lineTo(98, 20)
    ..lineTo(118, 20)
    ..quadraticBezierTo(126, 20, 130, 27)
    ..lineTo(136, 38)
    ..lineTo(144, 41)
    ..quadraticBezierTo(150, 43, 150, 50)
    ..lineTo(150, 58)
    ..quadraticBezierTo(150, 62, 146, 62)
    ..lineTo(6, 62)
    ..quadraticBezierTo(0, 62, 0, 56)
    ..lineTo(0, 16)
    ..quadraticBezierTo(0, 8, 8, 8)
    ..close();
  c.drawPath(body, _fill(Colors.white));
  c.save();
  c.clipPath(body);
  c.drawRect(const Rect.fromLTWH(0, 41, 150, 7), _fill(_red));
  c.drawRect(
    const Rect.fromLTWH(0, 54, 150, 8),
    _fill(const Color(0xFFE3EAF2)),
  );
  c.restore();
  c.drawPath(body, _stroke(_line, 1.5));

  // Cab window.
  final window = Path()
    ..moveTo(105, 26)
    ..lineTo(117, 26)
    ..quadraticBezierTo(121, 26, 123, 29)
    ..lineTo(128, 37)
    ..lineTo(105, 37)
    ..close();
  c.drawPath(window, _fill(_sky));
  c.drawPath(window, _stroke(_sky, 2));

  // Rear window and the cross on the box.
  c.drawRRect(_rr(const Rect.fromLTWH(66, 17, 22, 15), 4), _fill(_sky));
  _cross(c, const Offset(36, 25), 22, _red);

  // Siren with light rays.
  c.drawRRect(_rr(const Rect.fromLTWH(101, 13, 14, 7), 3), _fill(_red));
  final ray = _stroke(_red.withAlpha(170), 2);
  c.drawLine(const Offset(108, 8), const Offset(108, 3), ray);
  c.drawLine(const Offset(100, 10), const Offset(96, 6), ray);
  c.drawLine(const Offset(116, 10), const Offset(120, 6), ray);

  // Headlight.
  c.drawRRect(
    _rr(const Rect.fromLTWH(144, 49, 6, 5), 2),
    _fill(const Color(0xFFFFC94D)),
  );

  for (final x in [30.0, 118.0]) {
    final hub = Offset(x, 62);
    c.drawCircle(hub, 12, _fill(_ink));
    c.drawCircle(hub, 5.5, _fill(const Color(0xFFCBD5E1)));
    c.drawCircle(hub, 2, _fill(_ink));
  }
  c.restore();
}

/// A hospital front. Unscaled it is 64 wide and stands on y = 70.
void _hospital(Canvas c, Offset origin, double scale) {
  c.save();
  c.translate(origin.dx, origin.dy);
  c.scale(scale);

  final wings = RRect.fromRectAndCorners(
    const Rect.fromLTWH(0, 28, 64, 42),
    topLeft: const Radius.circular(4),
    topRight: const Radius.circular(4),
  );
  c.drawRRect(wings, _fill(const Color(0xFFF2F6FB)));
  c.drawRRect(wings, _stroke(_line, 1.2));

  final tower = RRect.fromRectAndCorners(
    const Rect.fromLTWH(16, 6, 32, 64),
    topLeft: const Radius.circular(5),
    topRight: const Radius.circular(5),
  );
  c.drawRRect(tower, _fill(Colors.white));
  c.drawRRect(tower, _stroke(_line, 1.2));

  // Sign.
  c.drawRRect(_rr(const Rect.fromLTWH(23, 12, 18, 18), 5), _fill(_red));
  _cross(c, const Offset(32, 21), 11, Colors.white);

  for (final w in const [
    Offset(4, 36),
    Offset(4, 50),
    Offset(52, 36),
    Offset(52, 50),
    Offset(21, 37),
    Offset(35, 37),
  ]) {
    c.drawRRect(_rr(Rect.fromLTWH(w.dx, w.dy, 8, 8), 2), _fill(_sky));
  }

  // Entrance with its awning.
  c.drawRRect(
    RRect.fromRectAndCorners(
      const Rect.fromLTWH(25, 54, 14, 16),
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
    ),
    _fill(_blue),
  );
  _bar(c, 21, 50, 22, 3.5, _red);
  c.restore();
}

/// Streets of a simple city map filling [area].
void _mapStreets(Canvas c, Rect area) {
  c.drawRect(area, _fill(_mapLand));
  final w = area.width;
  final h = area.height;
  Offset p(double x, double y) => area.topLeft + Offset(w * x, h * y);

  c.drawRRect(
    _rr(Rect.fromPoints(p(0.06, 0.08), p(0.34, 0.26)), 6),
    _fill(const Color(0xFFCDE8D3)),
  );
  c.drawRRect(
    _rr(Rect.fromPoints(p(0.72, 0.52), p(1.1, 0.7)), 6),
    _fill(const Color(0xFFBFDCF2)),
  );

  final road = _stroke(Colors.white, 8);
  c.drawLine(p(-0.1, 0.34), p(1.1, 0.26), road);
  c.drawLine(p(-0.1, 0.6), p(1.1, 0.74), road);
  c.drawLine(p(0.42, -0.1), p(0.3, 1.1), road);
  c.drawLine(p(0.84, -0.1), p(0.66, 1.1), road);
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient 1
// ─────────────────────────────────────────────────────────────────────────────

class _SosPainter extends CustomPainter {
  const _SosPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // The call going out.
    const center = Offset(150, 152);
    canvas.drawCircle(center, 124, _stroke(_red.withAlpha(30), 2));
    canvas.drawCircle(center, 98, _stroke(_red.withAlpha(48), 2));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.07);
    _phone(
      canvas,
      Rect.fromCenter(center: Offset.zero, width: 126, height: 220),
      (c, screen) {
        final left = screen.left;
        final top = screen.top;
        _bar(c, left + 14, top + 26, 54, 7, _ink.withAlpha(215));
        _bar(c, left + 14, top + 40, 34, 5, _ink.withAlpha(60));

        // Press-and-hold button with its progress ring.
        final button = Offset(screen.center.dx, top + 106);
        c.drawCircle(button, 50, _fill(_red.withAlpha(20)));
        c.drawCircle(button, 39, _stroke(_red.withAlpha(50), 4.5));
        c.drawArc(
          Rect.fromCircle(center: button, radius: 39),
          -math.pi / 2,
          math.pi * 1.35,
          false,
          _stroke(_red, 4.5),
        );
        c.drawCircle(
          button,
          29,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.4, -0.5),
              radius: 1.1,
              colors: [Color(0xFFEF5350), _red],
            ).createShader(Rect.fromCircle(center: button, radius: 29)),
        );
        _cross(c, button, 27, Colors.white);

        // Location that goes with the call.
        c.drawRRect(
          _rr(Rect.fromLTWH(left + 12, top + 168, 92, 26), 13),
          _fill(const Color(0xFFF1F4F8)),
        );
        _pin(c, Offset(left + 27, top + 188), 15, _red);
        _bar(c, left + 38, top + 175, 46, 5, _ink.withAlpha(150));
        _bar(c, left + 38, top + 184, 30, 4, _ink.withAlpha(60));
      },
    );
    canvas.restore();

    // "Location sent".
    _card(canvas, const Rect.fromLTWH(166, 56, 80, 38), 12);
    _pin(canvas, const Offset(184, 86), 22, _blue);
    _bar(canvas, 198, 67, 34, 6, _ink.withAlpha(215));
    _bar(canvas, 198, 78, 22, 4, _ink.withAlpha(70));
    canvas.drawCircle(const Offset(244, 58), 10, _fill(Colors.white));
    canvas.drawCircle(const Offset(244, 58), 8, _fill(_green));
    canvas.drawPath(
      Path()
        ..moveTo(240.2, 58.2)
        ..lineTo(243, 61)
        ..lineTo(248, 55.4),
      _stroke(Colors.white, 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient 2
// ─────────────────────────────────────────────────────────────────────────────

class _NearestPainter extends CustomPainter {
  const _NearestPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // City blocks under the search.
    canvas.save();
    canvas.translate(150, 150);
    canvas.rotate(-0.21);
    for (var x = -190.0; x < 190; x += 58) {
      for (var y = -190.0; y < 190; y += 58) {
        canvas.drawRRect(
          _rr(Rect.fromLTWH(x, y, 48, 48), 8),
          _fill(Colors.white.withAlpha(120)),
        );
      }
    }
    canvas.restore();

    const patient = Offset(150, 160);
    const nearest = Offset(216, 96);

    // Widening search rings.
    canvas.drawCircle(patient, 118, _stroke(_blue.withAlpha(46), 2));
    canvas.drawCircle(patient, 80, _stroke(_blue.withAlpha(76), 2));
    canvas.drawCircle(patient, 42, _fill(_blue.withAlpha(26)));
    canvas.drawCircle(patient, 42, _stroke(_blue.withAlpha(120), 2));

    // Ambulances that are further away.
    _ambulanceMarker(canvas, const Offset(70, 108), 14, active: false);
    _ambulanceMarker(canvas, const Offset(226, 224), 14, active: false);

    // The link to the nearest one.
    _dashed(
      canvas,
      Path()
        ..moveTo(patient.dx + 8, patient.dy - 34)
        ..lineTo(nearest.dx - 15, nearest.dy + 15),
      _stroke(_red, 3),
      on: 5,
      off: 6,
    );
    canvas.drawCircle(nearest, 30, _fill(_red.withAlpha(34)));
    _ambulanceMarker(canvas, nearest, 21);

    // Patient.
    canvas.drawOval(
      Rect.fromCenter(center: patient, width: 22, height: 8),
      _fill(_ink.withAlpha(46)),
    );
    _pin(canvas, patient, 46, _blue);

    // Hospital told in advance.
    _card(canvas, const Rect.fromLTWH(52, 190, 50, 50), 14);
    _hospital(canvas, const Offset(59, 194), 0.56);
    canvas.drawCircle(const Offset(100, 192), 8.5, _fill(Colors.white));
    canvas.drawCircle(const Offset(100, 192), 6, _fill(_green));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient 3
// ─────────────────────────────────────────────────────────────────────────────

class _TrackingPainter extends CustomPainter {
  const _TrackingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _phone(
      canvas,
      Rect.fromCenter(center: const Offset(160, 150), width: 130, height: 228),
      (c, screen) {
        _mapStreets(c, screen);

        const ambulance = Offset(128, 176);
        const home = Offset(192, 96);
        final route = Path()
          ..moveTo(ambulance.dx, ambulance.dy)
          ..cubicTo(140, 140, 186, 160, 176, 124)
          ..cubicTo(172, 110, 186, 104, home.dx, home.dy);
        c.drawPath(route, _stroke(Colors.white, 8));
        c.drawPath(route, _stroke(_blue, 4.5));

        c.drawCircle(home, 5, _fill(_blue));
        _pin(c, home, 32, _red);

        c.drawCircle(ambulance, 19, _fill(_red.withAlpha(40)));
        _ambulanceMarker(c, ambulance, 12);

        // Driver sheet with the call button.
        final sheet = RRect.fromRectAndCorners(
          Rect.fromLTRB(
            screen.left,
            screen.bottom - 54,
            screen.right,
            screen.bottom,
          ),
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
        );
        _shadow(c, sheet, blur: 8, dy: -3);
        c.drawRRect(sheet, _fill(Colors.white));
        final y = screen.bottom - 25;
        _bar(c, screen.center.dx - 11, screen.bottom - 48, 22, 3.5, _line);
        c.drawCircle(
          Offset(screen.left + 22, y),
          11,
          _fill(const Color(0xFFE3EDFC)),
        );
        c.drawCircle(Offset(screen.left + 22, y - 3), 4, _fill(_blue));
        c.drawArc(
          Rect.fromCircle(center: Offset(screen.left + 22, y + 9), radius: 7.5),
          math.pi,
          math.pi,
          true,
          _fill(_blue),
        );
        _bar(c, screen.left + 40, y - 8, 36, 6, _ink.withAlpha(215));
        _bar(c, screen.left + 40, y + 3, 24, 4, _ink.withAlpha(70));
        c.drawCircle(Offset(screen.right - 22, y), 13, _fill(_green));
        _icon(
          c,
          Icons.phone_rounded,
          Offset(screen.right - 22, y),
          15,
          Colors.white,
        );
      },
    );

    // Estimated arrival.
    _card(canvas, const Rect.fromLTWH(26, 74, 96, 48), 14);
    canvas.drawCircle(const Offset(49, 98), 13, _fill(const Color(0xFFE3EDFC)));
    canvas.drawCircle(const Offset(49, 98), 7.5, _stroke(_blue, 2.2));
    canvas.drawPath(
      Path()
        ..moveTo(49, 93.5)
        ..lineTo(49, 98)
        ..lineTo(52.2, 100),
      _stroke(_blue, 2.2),
    );
    _text(canvas, '4 mnt', const Offset(90, 93), size: 15);
    _bar(canvas, 70, 105, 34, 4, _ink.withAlpha(70));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver 1
// ─────────────────────────────────────────────────────────────────────────────

class _OrderAlertPainter extends CustomPainter {
  const _OrderAlertPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Dashboard and the stem of the phone mount.
    canvas.drawRRect(
      _rr(const Rect.fromLTWH(8, 238, 284, 100), 40),
      _fill(_ink),
    );
    _bar(canvas, 112, 256, 76, 6, Colors.white.withAlpha(30));
    canvas.drawRRect(
      _rr(const Rect.fromLTWH(140, 212, 20, 34), 5),
      _fill(_inkSoft),
    );

    _phone(
      canvas,
      Rect.fromCenter(center: const Offset(150, 122), width: 118, height: 196),
      (c, screen) {
        final cx = screen.center.dx;
        final top = screen.top;

        c.drawRect(
          Rect.fromLTWH(screen.left, top, screen.width, 46),
          _fill(const Color(0xFFFDECEC)),
        );
        c.drawRRect(
          _rr(
            Rect.fromCenter(
              center: Offset(cx, top + 24),
              width: 58,
              height: 16,
            ),
            8,
          ),
          _fill(_red),
        );
        _text(
          c,
          'DARURAT',
          Offset(cx, top + 24.5),
          size: 8,
          color: Colors.white,
          spacing: 0.8,
        );

        // 30 seconds to answer.
        final ring = Offset(cx, top + 86);
        c.drawCircle(ring, 27, _stroke(const Color(0xFFE5E7EB), 6));
        c.drawArc(
          Rect.fromCircle(center: ring, radius: 27),
          -math.pi / 2,
          math.pi * 1.55,
          false,
          _stroke(_red, 6),
        );
        _text(c, '30', ring, size: 21);

        _pin(c, Offset(screen.left + 20, top + 141), 15, _red);
        _bar(c, screen.left + 31, top + 128, 52, 5, _ink.withAlpha(215));
        _bar(c, screen.left + 31, top + 137, 34, 4, _ink.withAlpha(70));

        // Decline / accept.
        final decline = Rect.fromLTWH(screen.left + 10, top + 152, 34, 24);
        final accept = Rect.fromLTRB(
          decline.right + 6,
          decline.top,
          screen.right - 10,
          decline.bottom,
        );
        c.drawRRect(_rr(decline, 8), _fill(const Color(0xFFEEF1F5)));
        final x = decline.center;
        final cross = _stroke(const Color(0xFF7C8798), 2.2);
        c.drawLine(x + const Offset(-4, -4), x + const Offset(4, 4), cross);
        c.drawLine(x + const Offset(4, -4), x + const Offset(-4, 4), cross);
        c.drawRRect(_rr(accept, 8), _fill(_green));
        final a = accept.center;
        c.drawPath(
          Path()
            ..moveTo(a.dx - 6, a.dy + 0.3)
            ..lineTo(a.dx - 1.8, a.dy + 4.4)
            ..lineTo(a.dx + 6, a.dy - 4),
          _stroke(Colors.white, 2.6),
        );
      },
    );

    // Cradle holding the phone.
    for (final x in [83.0, 207.0]) {
      canvas.drawRRect(_rr(Rect.fromLTWH(x, 186, 10, 34), 5), _fill(_inkSoft));
    }
    canvas.drawRRect(
      _rr(const Rect.fromLTWH(83, 212, 134, 12), 6),
      _fill(_inkSoft),
    );

    // It rings loudly.
    const bell = Offset(226, 84);
    for (final (radius, alpha) in [(31.0, 150), (41.0, 80)]) {
      canvas.drawArc(
        Rect.fromCircle(center: bell, radius: radius),
        -1.15,
        1.3,
        false,
        _stroke(_blue.withAlpha(alpha), 3),
      );
    }
    canvas.drawCircle(
      bell + const Offset(0, 4),
      21,
      Paint()
        ..color = _ink.withAlpha(46)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(bell, 21, _fill(_blue));
    _icon(canvas, Icons.notifications_rounded, bell, 24, Colors.white);
    canvas.drawCircle(bell + const Offset(14, -15), 7.5, _fill(Colors.white));
    canvas.drawCircle(bell + const Offset(14, -15), 5.5, _fill(_red));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver 2
// ─────────────────────────────────────────────────────────────────────────────

class _HospitalRoutePainter extends CustomPainter {
  const _HospitalRoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const ground = 216.0;

    // Skyline, then the road.
    for (final (x, w, h) in [
      (84.0, 28.0, 84.0),
      (116.0, 34.0, 66.0),
      (154.0, 26.0, 94.0),
      (184.0, 22.0, 72.0),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, ground - h, w, h),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        _fill(const Color(0xFFD3E4F6)),
      );
    }
    canvas.drawRect(
      const Rect.fromLTWH(0, ground, 300, 84),
      _fill(const Color(0xFFC5D8EC)),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, ground, 300, 4),
      _fill(const Color(0xFFB3CAE2)),
    );
    for (var x = 30.0; x < 300; x += 44) {
      _bar(canvas, x, 258, 22, 4, Colors.white.withAlpha(220));
    }

    // Hospital at the end of the trip, patient at the start.
    _hospital(canvas, const Offset(212, 139), 1.1);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(40, ground), width: 22, height: 7),
      _fill(_ink.withAlpha(46)),
    );
    _pin(canvas, const Offset(40, ground - 1), 46, _blue);

    // The route between them.
    final route = Path()
      ..moveTo(40, 156)
      ..cubicTo(52, 62, 206, 40, 247, 130);
    _dashed(canvas, route, _stroke(_blue, 4), on: 9, off: 8);
    canvas.drawCircle(const Offset(40, 156), 6, _fill(Colors.white));
    canvas.drawCircle(const Offset(40, 156), 4, _fill(_blue));
    canvas.drawCircle(const Offset(247, 132), 6.5, _fill(Colors.white));
    canvas.drawCircle(const Offset(247, 132), 4.5, _fill(_blue));

    // The ambulance on its way.
    _ambulance(canvas, const Offset(70, 156), 0.94);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
