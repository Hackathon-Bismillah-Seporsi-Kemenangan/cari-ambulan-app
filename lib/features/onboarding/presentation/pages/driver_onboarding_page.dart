import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../widgets/onboarding_illustrations.dart';

// Warna lokal agar tampilan sesuai desain.
const _kBlue = Color(0xFF1565C0);
const _kDotIdle = Color(0xFFE5E7EB);
const _kCircle = Color(0xFFE6F1FC);

class _SlideData {
  final String title;
  final String body;
  final Widget illustration;

  const _SlideData({
    required this.title,
    required this.body,
    required this.illustration,
  });
}

/// Driver Ambulans onboarding flow (2 slides).
class DriverOnboardingPage extends StatefulWidget {
  final Future<void> Function() onCompleted;
  final VoidCallback onBack;

  const DriverOnboardingPage({
    super.key,
    required this.onCompleted,
    required this.onBack,
  });

  @override
  State<DriverOnboardingPage> createState() => _DriverOnboardingPageState();
}

class _DriverOnboardingPageState extends State<DriverOnboardingPage> {
  final PageController _controller = PageController();
  bool _busy = false;

  late final List<_SlideData> _slides = [
    _SlideData(
      title: AppStrings.driverOnboard1Title,
      body: AppStrings.driverOnboard1Desc,
      illustration: const OrderAlertIllustration(),
    ),
    _SlideData(
      title: AppStrings.driverOnboard2Title,
      body: AppStrings.driverOnboard2Desc,
      illustration: const HospitalRouteIllustration(),
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
    if (_page.round() >= _slides.length - 1) {
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
                // No back arrow, as in the design; Android back still leads
                // to the role choice.
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                child: Row(
                  children: [
                    const BrandMark(size: 26, color: _kBlue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        AppStrings.driverAppName,
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

              // ── Bottom bar
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
                                color: Color.lerp(_kDotIdle, _kBlue, t),
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
  final double delta;

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
                            decoration: const BoxDecoration(
                              color: _kCircle,
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
                            color: _kBlue,
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
