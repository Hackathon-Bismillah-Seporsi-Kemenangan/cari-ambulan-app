import 'dart:math' as math;
import 'dart:ui' show PathMetric, lerpDouble;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

// Warna lokal agar tampilan sesuai desain Figma.
const _kBlue = Color(0xFF1565C0);
const _kRed = Color(0xFFE53935);
const _kDotIdle = Color(0xFFE5E7EB);
const _kInk = Color(0xFF1B2A4A);

class _SlideData {
  final String title;
  final String body;
  final Color circleColor;
  final Widget illustration;

  const _SlideData({
    required this.title,
    required this.body,
    required this.circleColor,
    required this.illustration,
  });
}

/// Patient / Keluarga onboarding flow (3 slides).
class PatientOnboardingPage extends StatefulWidget {
  final Future<void> Function() onCompleted;
  final VoidCallback onBack;

  const PatientOnboardingPage({
    super.key,
    required this.onCompleted,
    required this.onBack,
  });

  @override
  State<PatientOnboardingPage> createState() => _PatientOnboardingPageState();
}

class _PatientOnboardingPageState extends State<PatientOnboardingPage> {
  final PageController _controller = PageController();
  bool _busy = false;

  late final List<_SlideData> _slides = [
    _SlideData(
      title: AppStrings.patientOnboard1Title,
      body: AppStrings.patientOnboard1Desc,
      circleColor: const Color(0xFFFDECEC),
      illustration: const _Illustration1(),
    ),
    _SlideData(
      title: AppStrings.patientOnboard2Title,
      body: AppStrings.patientOnboard2Desc,
      circleColor: const Color(0xFFE3F0FC),
      illustration: const _Illustration2(),
    ),
    _SlideData(
      title: AppStrings.patientOnboard3Title,
      body: AppStrings.patientOnboard3Desc,
      circleColor: const Color(0xFFE6F4EA),
      illustration: const _Illustration3(),
    ),
  ];

  double get _page {
    if (_controller.hasClients && _controller.position.haveDimensions) {
      return _controller.page ?? 0;
    }
    return 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDone() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onCompleted();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Onboarding belum tersimpan. Coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onBack() {
    if (_busy) return;
    if (_page.round() == 0) {
      widget.onBack();
    } else {
      _controller.previousPage(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onNext() {
    if (_busy || _controller.position.isScrollingNotifier.value) return;
    final current = _page.round();
    if (current >= _slides.length - 1) {
      _onDone();
    } else {
      _controller.nextPage(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // With no back arrow, Android back goes to the previous slide, then to
    // the role choice.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header
              Padding(
                // "Lewati"'s own 12 dp padding brings it to the 24 dp edge.
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _kRed,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        AppStrings.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _onDone,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text(AppStrings.skip),
                    ),
                  ],
                ),
              ),

              // ── Slides
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final delta = MediaQuery.disableAnimationsOf(context)
                            ? 0.0
                            : (_page - index).clamp(-1.0, 1.0);
                        return _SlideView(
                          data: _slides[index],
                          index: index,
                          total: _slides.length,
                          delta: delta,
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Bottom bar: dots + button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final page = _page;
                    final isLast = page.round() >= _slides.length - 1;
                    return Row(
                      children: [
                        Row(
                          children: List.generate(_slides.length, (i) {
                            final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              width: lerpDouble(6, 20, t),
                              height: 6,
                              decoration: BoxDecoration(
                                color: Color.lerp(_kDotIdle, _kRed, t),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _NextButton(
                              label: _busy
                                  ? 'Tunggu...'
                                  : isLast
                                  ? AppStrings.start
                                  : AppStrings.next,
                              onTap: _busy ? null : _onNext,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide content with parallax / fade
// ─────────────────────────────────────────────────────────────────────────────

class _SlideView extends StatelessWidget {
  final _SlideData data;
  final int index;
  final int total;
  final double delta; // -1..1, 0 = fully visible

  const _SlideView({
    required this.data,
    required this.index,
    required this.total,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final abs = delta.abs();
    final number =
        '${(index + 1).toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}';

    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Illustration (circle) — parallax + scale + fade
            SizedBox(
              height: (viewport.maxHeight * 0.56).clamp(160.0, 360.0),
              child: LayoutBuilder(
                builder: (context, c) {
                  final size = math.min(c.maxWidth - 48, c.maxHeight - 8);
                  return Center(
                    child: Transform.translate(
                      offset: Offset(delta * 70, 0),
                      child: Transform.scale(
                        scale: 1 - abs * 0.18,
                        child: Opacity(
                          opacity: (1 - abs * 0.9).clamp(0.0, 1.0),
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: data.circleColor,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: 300,
                                  height: 300,
                                  child: data.illustration,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Text — fades & slides slightly faster than the page
            Opacity(
              opacity: (1 - abs * 1.4).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(delta * 36, 0),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          number,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kRed,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data.body,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Next / Start button
// ─────────────────────────────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _NextButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kBlue,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustrations (dibuat dari widget, ukuran desain 300x300)
// Ganti dengan SVG/Lottie/PNG asli kalau sudah ada aset dari desainer.
// ─────────────────────────────────────────────────────────────────────────────

class _Phone extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  const _Phone({
    required this.width,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _kInk,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Colors.white, child: child),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: width * 0.32,
                height: 8,
                decoration: const BoxDecoration(
                  color: _kInk,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(8),
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

/// Slide 1 — tangan memegang HP dengan tombol SOS
class _Illustration1 extends StatelessWidget {
  const _Illustration1();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // tangan
        Positioned(
          right: 52,
          bottom: 38,
          child: Transform.rotate(
            angle: -0.08,
            child: Container(
              width: 74,
              height: 130,
              decoration: BoxDecoration(
                color: const Color(0xFFBBDDF7),
                borderRadius: BorderRadius.circular(36),
              ),
            ),
          ),
        ),
        for (final dy in [-30.0, -2.0, 26.0])
          Positioned(
            right: 36,
            top: 150 + dy,
            child: Container(
              width: 40,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFA8D2F3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        // HP
        _Phone(
          width: 130,
          height: 224,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final s in [96.0, 74.0])
                  Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kRed.withAlpha(s > 80 ? 22 : 40),
                    ),
                  ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: _kRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 38,
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

/// Slide 2 — ambulans melaju di jalan menuju lokasi
class _Illustration2 extends StatelessWidget {
  const _Illustration2();

  @override
  Widget build(BuildContext context) {
    Widget building(double w, double h, Color c) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );

    return Stack(
      children: [
        // jalan
        Positioned(
          left: -20,
          right: -20,
          bottom: 52,
          child: Transform.rotate(
            angle: -0.22,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFB9D3EA),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
        // gedung
        Positioned(
          left: 108,
          top: 70,
          child: building(36, 78, const Color(0xFFCFE0F1)),
        ),
        Positioned(
          left: 148,
          top: 56,
          child: building(40, 92, const Color(0xFFD9E7F5)),
        ),
        Positioned(
          left: 190,
          top: 84,
          child: building(32, 64, const Color(0xFFC3D8EC)),
        ),
        // pohon
        for (final p in [
          const Offset(60, 120),
          const Offset(84, 134),
          const Offset(232, 126),
        ])
          Positioned(
            left: p.dx,
            top: p.dy,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFF8FCB9B),
                shape: BoxShape.circle,
              ),
            ),
          ),
        // pin
        const Positioned(
          right: 52,
          top: 40,
          child: Icon(Icons.location_on_rounded, color: _kBlue, size: 44),
        ),
        // garis kecepatan
        for (final i in [0, 1, 2])
          Positioned(
            left: 36.0 + i * 6,
            top: 178.0 + i * 12,
            child: Container(
              width: 34 - i * 6.0,
              height: 4,
              decoration: BoxDecoration(
                color: _kBlue.withAlpha(110),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        // ambulans
        Positioned(
          left: 78,
          top: 156,
          child: Transform.rotate(angle: -0.1, child: const _Ambulance()),
        ),
      ],
    );
  }
}

class _Ambulance extends StatelessWidget {
  const _Ambulance();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 84,
      child: Stack(
        children: [
          // sirine
          Positioned(
            left: 52,
            top: 0,
            child: Container(
              width: 26,
              height: 9,
              decoration: BoxDecoration(
                color: _kRed,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // bodi
          Positioned(
            left: 0,
            right: 0,
            top: 8,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD5DEE8), width: 1.5),
              ),
            ),
          ),
          // strip merah
          Positioned(
            left: 2,
            right: 2,
            top: 44,
            height: 8,
            child: Container(color: _kRed),
          ),
          // kabin / kaca
          Positioned(
            right: 8,
            top: 16,
            child: Container(
              width: 38,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF9CC9F0),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          // palang
          const Positioned(
            left: 22,
            top: 14,
            child: Icon(Icons.add_rounded, color: _kRed, size: 34),
          ),
          // roda
          for (final x in [22.0, 104.0])
            Positioned(
              left: x,
              top: 50,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _kInk,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Slide 3 — peta real-time dengan rute dan estimasi waktu
class _Illustration3 extends StatelessWidget {
  const _Illustration3();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _Phone(
          width: 136,
          height: 232,
          child: CustomPaint(painter: _MapPainter(), size: Size.infinite),
        ),
        // ambulans kecil
        Positioned(
          left: 84,
          top: 168,
          child: Container(
            width: 26,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _kRed, width: 2),
            ),
            child: const Icon(Icons.add_rounded, color: _kRed, size: 12),
          ),
        ),
        // badge jam
        Positioned(
          right: 74,
          bottom: 46,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.access_time_filled_rounded,
              color: _kBlue,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEAF1F7),
    );

    // area hijau & air
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.62, w * 0.34, h * 0.2),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFCDE8D3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.58, h * 0.1, w * 0.3, h * 0.14),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFBFDCF2),
    );

    // jalan
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, h * 0.3), Offset(w, h * 0.42), road);
    canvas.drawLine(Offset(0, h * 0.7), Offset(w, h * 0.58), road);
    canvas.drawLine(Offset(w * 0.3, 0), Offset(w * 0.4, h), road);
    canvas.drawLine(Offset(w * 0.72, 0), Offset(w * 0.64, h), road);

    // rute putus-putus
    final path = Path()
      ..moveTo(w * 0.28, h * 0.74)
      ..cubicTo(w * 0.34, h * 0.56, w * 0.7, h * 0.64, w * 0.6, h * 0.42)
      ..cubicTo(w * 0.54, h * 0.28, w * 0.68, h * 0.24, w * 0.7, h * 0.18);
    final dash = Paint()
      ..color = _kBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final PathMetric m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), dash);
        d += 11;
      }
    }

    // pin tujuan
    final pin = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.location_on_rounded.codePoint),
        style: TextStyle(
          fontFamily: Icons.location_on_rounded.fontFamily,
          package: Icons.location_on_rounded.fontPackage,
          fontSize: 30,
          color: _kBlue,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pin.paint(canvas, Offset(w * 0.7 - pin.width / 2, h * 0.18 - pin.height));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
